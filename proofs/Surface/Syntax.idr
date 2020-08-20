module Surface.Syntax

%default total
%access public export

record ADTLabel where
  constructor MkADTLabel
  lbl : String

record Var where
  constructor MkVar
  var : String

Eq Var where
  (==) v1 v2 = var v1 == var v2
  (/=) v1 v2 = var v1 /= var v2

DecEq Var where
  decEq (MkVar var1) (MkVar var2) = case decEq var1 var2 of
                                         Yes Refl => Yes Refl
                                         No contra => No $ \Refl => contra Refl

mutual
  data STerm : Type where
    SVar  : (var : Var) -> STerm
    SLam  : (var : Var) -> (t : SType) -> (e : STerm) -> STerm
    SApp  : (e1 : STerm) -> (e2 : STerm) -> STerm
    SUnit : STerm
    SCase : (scrut : STerm) -> (branches : List CaseBranch) -> STerm
    SCon  : (lbl : ADTLabel) -> (body : STerm) -> (adtCons : ADTCons) -> STerm

  record CaseBranch where
    constructor MkCaseBranch
    lbl : ADTLabel
    var : Var
    body : STerm

  data BaseType = BUnit

  infixl 6 &
  infixl 7 |=|
  data Refinement = (|=|) STerm STerm
                  | (&) Refinement Refinement
  %name Refinement r, r1, r2

  ADTCons : Type
  ADTCons = List (ADTLabel, SType)

  data SType : Type where
    SRBT : (var : Var) -> (b : BaseType) -> (ref : Refinement) -> SType
    SArr : (var : Var) -> (t1 : SType) -> (t2 : SType) -> SType
    SADT : (cons : ADTCons) -> SType

isValue : STerm -> Bool
isValue (SVar _) = True
isValue SUnit = True
isValue (SCon _ body _) = isValue body
isValue _ = False

data Ctx = MkCtx (List (Var, SType))

-- Helpers

Empty : Ctx
Empty = MkCtx []

(::) : (Var, SType) -> Ctx -> Ctx
(::) p (MkCtx lst) = MkCtx $ p :: lst

Τ : Refinement
Τ = SUnit |=| SUnit

syntax "{" [v] ":" [b] "|" [r] "}" = SRBT v b r

mutual
  SubstInType : Var -> STerm -> SType -> SType
  SubstInType x e (SRBT var b ref) = SRBT var b $ SubstInRef x e ref
  SubstInType x e (SArr var t1 t2) = SArr var (SubstInType x e t1) (SubstInType x e t2)
  SubstInType x e (SADT cons) = SADT $ SubstInADT x e cons

  SubstInRef : Var -> STerm -> Refinement -> Refinement
  SubstInRef x e (e1 |=| e2) = SubstInTerm x e e1 |=| SubstInTerm x e e2
  SubstInRef x e (r1 & r2) = SubstInRef x e r1 & SubstInRef x e r2

  SubstInTerm : Var -> STerm -> STerm -> STerm
  SubstInTerm x e (SVar var) = case decEq x var of
                                    Yes _ => e
                                    No _ => SVar var
  SubstInTerm x e (SLam var t body) = SLam var t $ case decEq x var of
                                                        Yes _ => body
                                                        No _ => SubstInTerm x e body
  SubstInTerm x e (SApp e1 e2) = SApp (SubstInTerm x e e1) (SubstInTerm x e e2)
  SubstInTerm x e SUnit = SUnit
  SubstInTerm x e (SCase scrut branches) = SCase (SubstInTerm x e scrut) (SubstInBranches x e branches)
  SubstInTerm x e (SCon lbl body adtCons) = SCon lbl (SubstInTerm x e body) (SubstInADT x e adtCons)

  SubstInADT : Var -> STerm -> ADTCons -> ADTCons
  SubstInADT x e [] = []
  SubstInADT x e ((lbl, ty) :: xs) = (lbl, SubstInType x e ty) :: SubstInADT x e xs
  -- TODO can we have `map` here while keeping the totality checker happy?

  SubstInBranches : Var -> STerm -> List CaseBranch -> List CaseBranch
  SubstInBranches x e [] = []
  SubstInBranches x e (b@(MkCaseBranch lbl var body) :: bs) =
    let this = case decEq x var of
                    Yes _ => b
                    No _ => MkCaseBranch lbl var $ SubstInTerm x e body
        rest = SubstInBranches x e bs
    in this :: rest
