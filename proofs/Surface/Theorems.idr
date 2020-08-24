module Surface.Theorems

import Data.Fin
import Data.List
import Data.Vect
import Data.Vect.Quantifiers

import Surface.Syntax
import Surface.Derivations

import Helpers

import Surface.Theorems.Lemmas
import Surface.Theorems.Thinning

%default total

twfWeaken : (g ok) -> (g |- ht) -> (g |- t) -> (((_, ht) :: g) |- t)
twfWeaken {g} gok htPrf tPrf = twfThinning (IgnoreHead $ sublistSelf g) (TCTX_Bind gok htPrf) tPrf

anyTypeInCtxIsWellformed : (g ok) -> Elem (x, t) g -> (g |- t)
anyTypeInCtxIsWellformed (TCTX_Bind init twfPrf) Here = twfWeaken init twfPrf twfPrf
anyTypeInCtxIsWellformed (TCTX_Bind init twfPrf) (There later) = twfWeaken init twfPrf $ anyTypeInCtxIsWellformed init later

substPreservesTWF : (t2 : SType) -> (((x, t1) :: g) |- t2) -> (g |- e : t1) -> (g |- substInType x e t2)
substPreservesTWF (SRBT var b _) (TWF_TrueRef (TCTX_Bind pref _)) eprf = TWF_TrueRef pref
substPreservesTWF (SRBT var b (e1 |=| e2)) (TWF_Base prfr1 prfr2) eprf = TWF_Base ?later ?later
substPreservesTWF (SRBT var b (r1 & r2)) (TWF_Conj prfr1 prfr2) eprf = TWF_Conj ?wut ?wut
substPreservesTWF (SArr var t1 t2) (TWF_Arr t1prf t2prf) eprf = TWF_Arr (substPreservesTWF t1 t1prf eprf) ?later -- (substPreservesTWF t2 ?wut ?wut)
substPreservesTWF (SADT cons) (TWF_ADT alls) eprf = TWF_ADT ?later

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
  T_implies_TWF : (g |- e : t) -> (g |- t)
  T_implies_TWF (T_Unit gok) = TWF_TrueRef gok
  T_implies_TWF (T_Var gok elemPrf) = anyTypeInCtxIsWellformed gok elemPrf
  T_implies_TWF (T_Abs arrWfPrf _) = arrWfPrf
  T_implies_TWF (T_App {t2} prf1 prf2) = substPreservesTWF t2 (arrWfImpliesCodWf $ T_implies_TWF prf1) prf2
  T_implies_TWF (T_Case wfPrf _ _) = wfPrf
  T_implies_TWF (T_Con _ wfPrf) = wfPrf
  T_implies_TWF (T_Sub x y) = ?T_implies_TWF_sub_hole
