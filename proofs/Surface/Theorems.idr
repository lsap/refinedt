module Surface.Theorems

import Data.Fin
import Data.List
import Data.Vect
import Data.Vect.Quantifiers

import Surface.Syntax
import Surface.Derivations

import Helpers

%default total

mutual
  -- Well-formedness of a type in a context implies well-formedness of said context
  -- TODO get rid of `assert_smaller` by carrying the depth of the tree explicitly
  TWF_implies_TCTX : (g |- t) -> g ok
  TWF_implies_TCTX (TWF_TrueRef gok) = gok
  TWF_implies_TCTX (TWF_Base t1 t2) = case TWF_implies_TCTX (assert_smaller (TWF_Base t1 t2) (T_implies_TWF t1)) of
                                           TCTX_Bind gok _ => gok
  TWF_implies_TCTX (TWF_Conj twfr1 _) = TWF_implies_TCTX twfr1
  TWF_implies_TCTX (TWF_Arr twft1 _) = TWF_implies_TCTX twft1
  TWF_implies_TCTX (TWF_ADT (con1Ty :: _)) = TWF_implies_TCTX con1Ty

  -- Well-typedness of a term in a context implies well-formedness of its type in said context

  twfThinning : Sublist g g' -> g' ok -> (g |- t) -> (g' |- t)
  twfThinning _      g'ok (TWF_TrueRef g') = TWF_TrueRef g'ok
  twfThinning subPrf g'ok (TWF_Base t1 t2) = let expCtxOk = TCTX_Bind g'ok (TWF_TrueRef g'ok)
                                              in TWF_Base (tThinning (AppendBoth subPrf) expCtxOk t1) (tThinning (AppendBoth subPrf) expCtxOk t2)
  twfThinning subPrf g'ok (TWF_Conj twfr1 twfr2) = TWF_Conj (twfThinning subPrf g'ok twfr1) (twfThinning subPrf g'ok twfr2)
  twfThinning subPrf g'ok (TWF_Arr twf1 twf2) = TWF_Arr
                                                  (twfThinning subPrf g'ok twf1)
                                                  (twfThinning (AppendBoth subPrf) (TCTX_Bind g'ok (twfThinning subPrf g'ok twf1)) twf2)
  twfThinning subPrf g'ok (TWF_ADT preds) = TWF_ADT (thinAll subPrf g'ok preds)
    where
      thinAll : Sublist g g' -> g' ok -> All (\t => g |- t) ls -> All (\t => g' |- t) ls
      thinAll _ _ [] = []
      thinAll subPrf g'ok (a :: as) = twfThinning subPrf g'ok a :: thinAll subPrf g'ok as

  twfWeaken : (g |- ht) -> (g |- t) -> (((_, ht) :: g) |- t)
  twfWeaken {g} hPrf ctxPrf = let g'ok = TCTX_Bind (TWF_implies_TCTX ctxPrf) hPrf
                               in twfThinning (IgnoreHead $ sublistSelf g) g'ok ctxPrf

  anyTypeInCtxIsWellformed : (g ok) -> Elem (x, t) g -> (g |- t)
  anyTypeInCtxIsWellformed (TCTX_Bind _ twfPrf) Here = twfWeaken twfPrf twfPrf
  anyTypeInCtxIsWellformed (TCTX_Bind init twfPrf) (There later) = twfWeaken twfPrf $ anyTypeInCtxIsWellformed init later

  tThinning : Sublist g g' -> g' ok -> (g |- e : t) -> (g' |- e : t)
  tThinning subPrf g'ok (T_Unit gokPrf) = T_Unit g'ok
  tThinning subPrf g'ok (T_Var _ elemPrf) = T_Var g'ok (superListHasElems subPrf elemPrf)
  tThinning subPrf g'ok (T_Abs body) = case TWF_implies_TCTX (T_implies_TWF body) of
                                            TCTX_Bind _ twf1 => T_Abs (tThinning (AppendBoth subPrf) (TCTX_Bind g'ok $ twfThinning subPrf g'ok twf1) body)
  tThinning subPrf g'ok (T_App t1 t2) = T_App (tThinning subPrf g'ok t1) (tThinning subPrf g'ok t2)
  tThinning subPrf g'ok (T_Case twf scrut branches) = T_Case (twfThinning subPrf g'ok twf) (tThinning subPrf g'ok scrut) branches
  tThinning subPrf g'ok (T_Con arg adtTy) = T_Con (tThinning subPrf g'ok arg) (twfThinning subPrf g'ok adtTy)
  tThinning subPrf g'ok (T_Sub x y) = ?thinning_sub_hole

  T_implies_TWF : (g |- e : t) -> (g |- t)
  T_implies_TWF (T_Unit _) = TWF_TrueRef
  T_implies_TWF (T_Var gok elemPrf) = anyTypeInCtxIsWellformed gok elemPrf
  T_implies_TWF (T_Abs y) = ?T_implies_TWF_rhs_3
  T_implies_TWF (T_App y z) = ?T_implies_TWF_rhs_4
  T_implies_TWF (T_Case x y z) = ?T_implies_TWF_rhs_5
  T_implies_TWF (T_Con x y) = ?T_implies_TWF_rhs_6
  T_implies_TWF (T_Sub x y) = ?T_implies_TWF_rhs_7
