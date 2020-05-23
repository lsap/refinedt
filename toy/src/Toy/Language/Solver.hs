{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RecordWildCards, QuasiQuotes, BlockArguments #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Toy.Language.Solver
( solve
, SolveContext
, SolveRes(..)

, buildCtx
) where

import qualified Data.HashMap.Strict as HM
import Data.Generics.Uniplate.Data
import Data.Maybe
import Data.String.Interpolate
import Control.Arrow
import Control.Monad
import Control.Monad.Reader
import Z3.Monad

import Toy.Language.Syntax.Decls
import Toy.Language.Syntax.Types

data SolveRes = Correct | Wrong deriving (Eq, Show)

newtype SolveContext = SolveContext
  { visibleSigs :: [FunSig]
  } deriving (Eq, Ord, Show, Semigroup, Monoid)

buildCtx :: [FunSig] -> SolveContext
buildCtx = SolveContext

solve :: SolveContext -> FunSig -> FunDef -> IO SolveRes
solve ctx sig def = evalZ3 $ mkScript ctx arg2type resType (funBody def)
  where
    (argTypes, resType) = splitTypes sig
    arg2type = zip (funArgs def) argTypes

type ArgTypes = [(VarName, Ty)]

newtype Z3VarName = Z3VarName { getZ3VarName :: AST }

newtype SolveEnvironment = SolveEnvironment
  { z3args :: HM.HashMap VarName (Ty, Z3VarName)
  }

-- This expects that the pi-binders names in the type are equal to the argument names in the definition.
-- TODO explicitly check for this.
mkScript :: SolveContext -> ArgTypes -> RefinedBaseTy -> Term -> Z3 SolveRes
mkScript ctx args target term = do
  argVars <- buildZ3Vars args
  ctxVars <- buildCtxVars $ visibleSigs ctx
  let solveEnv = SolveEnvironment $ argVars <> ctxVars

  convertZ3Result <$> flip runReaderT solveEnv do
    argsPresup <- genArgsPresup

    res <- Z3VarName <$> mkFreshIntVar "_res$" -- TODO don't assume result : Int
    resConcl <- genRefinementCstrs target res >>= mkAnd

    typedTerm <- annotateTypes term

    TermsCstrs { .. } <- genTermsCstrs res typedTerm
    case mandatoryCstrs of
         Just cstrs -> assert cstrs
         Nothing -> pure ()
    refutables <- maybe mkTrue pure refutableCstrs
    termCstrsConsistent <- solverCheckAssumptions [refutables]
    case termCstrsConsistent of
         Sat -> do
            assert refutables
            assert =<< mkNot =<< argsPresup `mkImplies` resConcl
            invert <$> check
         c -> pure c

    {-
    res <- check
    getModel >>= modelToString . fromJust . snd >>= liftIO . putStrLn
    pure $ invert res
    -}
  where
    invert Sat = Unsat
    invert Unsat = Sat
    invert Undef = Undef

buildZ3Vars :: ArgTypes -> Z3 (HM.HashMap VarName (Ty, Z3VarName))
buildZ3Vars args =
  HM.fromList <$> mapM (mapM sequence) [ (var, (ty, Z3VarName <$> mkZ3Var (getName var) ty))
                                       | (var, ty) <- args
                                       ]
  where
    mkZ3Var varName (TyBase RefinedBaseTy { baseType = TInt }) = mkFreshIntVar varName
    mkZ3Var varName _ = mkStringSymbol varName >>= mkUninterpretedSort >>= mkFreshConst varName -- TODO fun decl?

buildCtxVars :: [FunSig] -> Z3 (HM.HashMap VarName (Ty, Z3VarName))
buildCtxVars sigs = buildZ3Vars [ (VarName funName, funTy) | FunSig { .. } <- sigs ]

type TypedTerm = TermT Ty

annotateTypes :: (MonadReader SolveEnvironment m) => Term -> m TypedTerm
annotateTypes (TName _ varName) = (`TName` varName) <$> askVarTy varName
annotateTypes (TInteger _ n) = pure $ TInteger (TyBase $ RefinedBaseTy TInt $ Refinement [AR ROpEq $ RArgInt n]) n
annotateTypes (TBinOp _ t1 op t2) = do
  t1' <- annotateTypes t1
  t2' <- annotateTypes t2
  expectBaseTy TInt $ annotation t1'
  expectBaseTy TInt $ annotation t2'
  let resTy = case op of
                   BinOpPlus -> TInt
                   BinOpMinus -> TInt
                   BinOpGt -> TBool
                   BinOpLt -> TBool
  -- this could have had a strong refinement if our refinements language supported arithmetic operations
  pure $ TBinOp (TyBase $ RefinedBaseTy resTy trueRefinement) t1' op t2'
annotateTypes TIfThenElse { .. } = do
  tcond' <- annotateTypes tcond
  expectBaseTy TBool $ annotation tcond'

  tthen' <- annotateTypes tthen
  telse' <- annotateTypes telse

  when (stripRefinements (annotation tthen') /= stripRefinements (annotation telse')) $ error [i|Type mismatch between #{tthen} and #{telse}|]

  pure $ TIfThenElse (annotation tthen') tcond' tthen' telse'
annotateTypes (TApp _ t1 t2) = do
  t1' <- annotateTypes t1
  t2' <- annotateTypes t2
  resTy <- case annotation t1' of
                TyArrow ArrowTy { .. } -> do
                  when (stripRefinements domTy /= stripRefinements (annotation t2'))
                      $ error [i|Type mismatch: expected #{domTy}, got #{annotation t2'}|]
                  pure case piVarName of
                            Nothing -> codTy
                            Just varName -> substPi varName t2 codTy
                _ -> error [i|Expected arrow type, got #{annotation t1'}|]
  pure $ TApp resTy t1' t2'

-- TODO occurs check - rename whatever can be shadowed
substPi :: VarName -> Term -> Ty -> Ty
substPi srcName (TName _ dstName) = transformBi f
  where
    f (RArgVar var) | var == srcName = RArgVar dstName
    f (RArgVarLen var) | var == srcName = RArgVarLen dstName
    f arg = arg
substPi srcName (TInteger _ n) = transformBi f
  where
    f (RArgVar var) | var == srcName = RArgInt n
    f (RArgVarLen var) | var == srcName = error [i|Can't substitute `len #{var}` with a number|]
    f arg = arg
substPi _ term = error [i|Unsupported substitution target: #{term}|]

data TermsCstrs = TermsCstrs
  { mandatoryCstrs :: Maybe AST
  , refutableCstrs :: Maybe AST
  }

mandatory :: AST -> TermsCstrs
mandatory cstr = TermsCstrs (Just cstr) Nothing

refutable :: AST -> TermsCstrs
refutable cstr = TermsCstrs Nothing (Just cstr)

andTermsCstrs :: MonadZ3 m => [TermsCstrs] -> m TermsCstrs
andTermsCstrs cstrs = TermsCstrs <$> mkAnd' mandatories <*> mkAnd' refutables
  where
    mandatories = mapMaybe mandatoryCstrs cstrs
    refutables = mapMaybe refutableCstrs cstrs
    mkAnd' [] = pure Nothing
    mkAnd' [c] = pure $ Just c
    mkAnd' cs = Just <$> mkAnd cs

implyTermsCstrs :: MonadZ3 m => AST -> TermsCstrs -> m TermsCstrs
implyTermsCstrs presupp TermsCstrs { .. } = do
  mandatory' <- mkImplies' mandatoryCstrs
  refutable' <- mkImplies' refutableCstrs
  pure $ TermsCstrs mandatory' refutable'
  where
    mkImplies' = traverse $ mkImplies presupp

genTermsCstrs :: (MonadZ3 m, MonadReader SolveEnvironment m) => Z3VarName -> TypedTerm -> m TermsCstrs
genTermsCstrs termVar (TName _ varName) = do
  z3Var <- askZ3VarName varName
  mandatory <$> getZ3VarName termVar `mkEq` z3Var
genTermsCstrs termVar (TInteger _ n) = do
  num <- mkIntNum n
  mandatory <$> getZ3VarName termVar `mkEq` num
genTermsCstrs termVar (TBinOp _ t1 op t2) = do
  (t1var, t1cstrs) <- mkVarCstrs "_linkVar_t1$" t1
  (t2var, t2cstrs) <- mkVarCstrs "_linkVar_t2$" t2
  bodyRes <- z3op t1var t2var
  bodyCstr <- mandatory <$> getZ3VarName termVar `mkEq` bodyRes
  andTermsCstrs [t1cstrs, t2cstrs, bodyCstr]
  where
    z3op = case op of
                BinOpPlus -> \a b -> mkAdd [a, b]
                BinOpMinus -> \a b -> mkSub [a, b]
                BinOpGt -> mkGt
                BinOpLt -> mkLt
genTermsCstrs termVar TIfThenElse { .. } = do
  condVar <- mkFreshBoolVar "_condVar$"
  condCstrs <- genTermsCstrs (Z3VarName condVar) tcond

  (thenVar, thenCstrs) <- mkVarCstrs "_linkVar_tthen$" tthen
  (elseVar, elseCstrs) <- mkVarCstrs "_linkVar_telse$" telse

  thenClause <- do
    thenEq <- mandatory <$> getZ3VarName termVar `mkEq` thenVar
    entails <- andTermsCstrs [thenCstrs, thenEq]
    implyTermsCstrs condVar entails
  elseClause <- do
    elseEq <- mandatory <$> getZ3VarName termVar `mkEq` elseVar
    notCondVar <- mkNot condVar
    entails <- andTermsCstrs [elseCstrs, elseEq]
    implyTermsCstrs notCondVar entails

  andTermsCstrs [condCstrs, thenClause, elseClause]
genTermsCstrs termVar (TApp resTy fun arg) = do
  subTyCstr <- case (annotation fun, annotation arg) of
                    (TyArrow ArrowTy { domTy = expectedTy }, actualTy) -> expectedTy <: actualTy
                    (_, _) -> error "Function should have arrow type (this should've been caught earlier though)"

  resCstr <- case resTy of
                  TyArrow _ -> pure Nothing
                  TyBase rbt -> fmap Just $ genRefinementCstrs rbt termVar >>= mkAnd

  pure $ TermsCstrs resCstr (Just subTyCstr)

-- generate constraints for the combination of the function type and its argument type:
-- the refinements of the first Ty should be a subtype (that is, imply) the refinements of the second Ty
(<:) :: (MonadZ3 m, MonadReader SolveEnvironment m) => Ty -> Ty -> m AST
TyBase rbtExpected <: TyBase rbtActual = do
  v <- Z3VarName <$> mkFreshIntVar "_∀_v$"

  actualCstr <- genRefinementCstrs rbtActual v >>= mkAnd
  expectedCstr <- genRefinementCstrs rbtExpected v >>= mkAnd
  implication <- mkImplies actualCstr expectedCstr

  v' <- toApp $ getZ3VarName v
  mkForallConst [] [v'] implication
TyArrow (ArrowTy _ funDomTy funCodTy) <: TyArrow (ArrowTy _ argDomTy argCodTy) = do
  argCstrs <- argDomTy <: funDomTy
  funCstrs <- funCodTy <: argCodTy
  mkAnd [argCstrs, funCstrs]
ty1 <: ty2 = error [i|Mismatched types #{ty1} #{ty2} (which should've been caught earlier though)|]

mkVarCstrs :: (MonadZ3 m, MonadReader SolveEnvironment m) => String -> TypedTerm -> m (AST, TermsCstrs)
mkVarCstrs name term = do
  -- TODO not necessarily int
  var <- mkFreshIntVar name
  cstrs <- genTermsCstrs (Z3VarName var) term
  pure (var, cstrs)

expectBaseTy :: Monad m => BaseTy -> Ty -> m ()
expectBaseTy expected (TyBase RefinedBaseTy { .. }) | baseType == expected = pure ()
expectBaseTy expected ty = error [i|Expected #{expected}, got #{ty} instead|]

genArgsPresup :: (MonadZ3 m, MonadReader SolveEnvironment m) => m AST
genArgsPresup = do
  args <- asks $ HM.elems . z3args
  foldM addVar [] args >>= mkAnd
  where
    addVar cstrs (TyBase rbTy, z3var) = (cstrs <>) <$> genRefinementCstrs rbTy z3var
    addVar cstrs _ = pure cstrs

genRefinementCstrs :: (MonadZ3 m, MonadReader SolveEnvironment m) => RefinedBaseTy -> Z3VarName -> m [AST]
genRefinementCstrs rbTy z3var
  | not $ null conjs = do
    when (baseType rbTy /= TInt) $ error "Non-int refinements unsupported for now"
    mapM (genCstr $ getZ3VarName z3var) conjs
  | otherwise = pure []
  where
    conjs = conjuncts $ baseTyRefinement rbTy

    genCstr v (AR op arg) = do
      z3arg <- case arg of
                    RArgInt n -> mkIntNum n
                    RArgVar var -> askZ3VarName var
                    RArgVarLen _ -> error "TODO" -- TODO
      v `z3op` z3arg
      where
        z3op = case op of
                    ROpLt -> mkLt
                    ROpLeq -> mkLe
                    ROpEq -> mkEq
                    ROpNEq -> \a b -> mkNot =<< mkEq a b
                    ROpGt -> mkGt
                    ROpGeq -> mkGe

askZ3VarName :: MonadReader SolveEnvironment m => VarName -> m AST
askZ3VarName var = getZ3VarName <$> asks (snd . (HM.! var) . z3args)

askVarTy :: MonadReader SolveEnvironment m => VarName -> m Ty
askVarTy var = asks (fst . (HM.! var) . z3args)

convertZ3Result :: Result -> SolveRes
convertZ3Result Sat = Correct
convertZ3Result Unsat = Wrong
convertZ3Result Undef = Wrong -- TODO

splitTypes :: FunSig -> ([Ty], RefinedBaseTy)
splitTypes = go . funTy
  where
    go (TyBase rbTy) = ([], rbTy)
    go (TyArrow ArrowTy { .. }) = first (domTy :) $ go codTy

instance MonadZ3 m => MonadZ3 (ReaderT r m) where
  getSolver = ReaderT $ const getSolver
  getContext = ReaderT $ const getContext
