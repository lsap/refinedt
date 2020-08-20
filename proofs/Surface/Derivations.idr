module Surface.Derivations

import Data.List.Quantifiers

import Surface.Syntax

%default total
%access public export

syntax [γ] "ok" = TCTX γ
syntax [γ] "|-" [t] = TWF γ t
syntax [y] "|-" [e] ":" [t] = T γ e t

mutual
  data TCTX : (γ : Ctx) -> Type where
    TCTX_Empty  : TCTX Empty
    TCTX_Bind   : TCTX γ -> (γ |- t) -> TCTX ((var, t) :: γ)

  data TWF : (γ : Ctx) -> (t : SType) -> Type where
    TWF_TrueRef : γ |- { v : b | Τ }
    TWF_Base    : (((v, { v : b1 | Τ }) :: γ) |- e1 : { v2 : b' | Τ })
               -> (((v, { v : b1 | Τ }) :: γ) |- e2 : { v2 : b' | Τ })
               -> (γ |- { v : b | e1 |=| e2 })
    TWF_Conj    : (γ |- { v : b | r1 })
               -> (γ |- { v : b | r2 })
               -> (γ |- { v : b | r1 & r2 })
    TWF_Arr     : (γ |- t1)
               -> (((x, t1) :: γ) |- t2)
               -> (γ |- SArr x t1 t2)
    TWF_ADT     : All (\(_, conTy) => γ |- conTy) adtCons
               -> (γ |- SADT adtCons)

  data T : (γ : Ctx) -> (e : STerm) -> (t : SType) -> Type where

  data ST : (γ : Ctx) -> (t1 : SType) -> (t2 : SType) -> Type where
