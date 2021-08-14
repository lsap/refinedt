{-# OPTIONS --safe #-}

module Surface.Safety where

open import Data.Fin using (zero; suc)
open import Data.Nat using (zero)
open import Data.Vec.Base using (lookup)
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Surface.Syntax
open import Surface.Syntax.Renaming as R
open import Surface.Syntax.Substitution.Stable
open import Surface.Derivations
open import Surface.Operational
open import Surface.Operational.BetaEquivalence
open import Surface.Theorems.Agreement
open import Surface.Theorems.Substitution
open import Surface.Theorems.Helpers
open import Surface.Safety.Helpers

data Progress (ε : STerm ℓ) : Set where
  step : (ε↝ε' : ε ↝ ε')
       → Progress ε
  done : (is-value : IsValue ε)
       → Progress ε

progress : ⊘ ⊢[ φ ] ε ⦂ τ
         → Progress ε
progress (T-Unit Γok) = done IV-Unit
progress (T-Abs arrδ εδ) = done IV-Abs
progress (T-App {ε₂ = ε₂} ε₁δ ε₂δ) with progress ε₁δ
... | step ε↝ε' = step (E-AppL ε↝ε')
... | done is-value-ε₁ with progress ε₂δ
...   | step ε↝ε' = step (E-AppR is-value-ε₁ ε↝ε')
...   | done is-value-ε₂ with canonical-⇒ ε₁δ is-value-ε₁ refl
...     | C-Lam = step (E-AppAbs is-value-ε₂)
progress (T-Case resδ εδ branches) with progress εδ
... | step ε↝ε' = step (E-CaseScrut ε↝ε')
... | done is-value with canonical-⊍ εδ is-value refl
...   | C-Con with is-value
...     | IV-ADT ε-value = step (E-CaseMatch ε-value _)
progress (T-Con _ εδ adtτ) with progress εδ
... | step ε↝ε' = step (E-ADT ε↝ε')
... | done is-value = done (IV-ADT is-value)
progress (T-Sub εδ τδ τ<:τ') = progress εδ
progress (T-RConv εδ _ τ↝τ') = progress εδ


preservation : ε ↝ ε'
             → Γ ⊢[ φ ] ε ⦂ τ
             → Γ ⊢[ φ ] ε' ⦂ τ
preservation ε↝ε' (T-Sub εδ Γ⊢τ' Γ⊢τ<:τ') = T-Sub (preservation ε↝ε' εδ) Γ⊢τ' Γ⊢τ<:τ'
preservation ε↝ε' (T-RConv εδ τ'δ τ↝τ') = T-RConv (preservation ε↝ε' εδ) τ'δ τ↝τ'
preservation (E-AppL ε↝ε') (T-App ε₁δ ε₂δ) = T-App (preservation ε↝ε' ε₁δ) ε₂δ
preservation (E-AppR x ε↝ε') (T-App ε₁δ ε₂δ)
  = let τ₂δ = arr-wf-⇒-cod-wf (Γ⊢ε⦂τ-⇒-Γ⊢τ ε₁δ)
        τ'δ = sub-Γ⊢τ-front ε₂δ τ₂δ
     in T-RConv (T-App ε₁δ (preservation ε↝ε' ε₂δ)) τ'δ (forward (↝βτ-Subst zero _ _ _ ε↝ε'))
preservation (E-AppAbs ε₂-is-value) (T-App ε₁δ ε₂δ) = sub-Γ⊢ε⦂τ-front ε₂δ (SLam-inv ε₁δ)
preservation (E-ADT ε↝ε') (T-Con ≡-prf εδ adtτ) = T-Con ≡-prf (preservation ε↝ε' εδ) adtτ
preservation (E-CaseScrut ε↝ε') (T-Case resδ εδ branches) = T-Case resδ (preservation ε↝ε' εδ) branches
preservation {φ = φ} (E-CaseMatch ε-is-value ι) (T-Case resδ εδ branches)
  = let branchδ = sub-Γ⊢ε⦂τ-front (con-has-type εδ) (branch-has-type ι branches)
     in subst-Γ⊢ε⦂τ-τ (replace-weakened-τ-zero _ _) branchδ
  where
  branch-has-type : ∀ {cons : ADTCons (Mkℕₐ n) ℓ} {bs : CaseBranches (Mkℕₐ n) ℓ} {τ}
                  → (ι : Fin n)
                  → BranchesHaveType φ Γ cons bs τ
                  → Γ , lookup cons ι ⊢[ φ ] CaseBranch.body (lookup bs ι) ⦂ R.weaken-τ τ
  branch-has-type zero (OneMoreBranch εδ _) = εδ
  branch-has-type (suc ι) (OneMoreBranch _ bht) = branch-has-type ι bht
