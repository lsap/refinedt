{-# OPTIONS --safe #-}

module Translation where

open import Data.Fin using (zero)
open import Data.Vec using (Vec; _∷_; [])
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Core.Syntax as C renaming (Γ to Γᶜ; ε to εᶜ)
open import Core.Syntax.Derived as C
open import Core.Syntax.Derived.Typing as C
open import Core.Syntax.Membership as C renaming (_∈_at_ to _∈ᶜ_at_)
open import Core.Syntax.Renaming as CR
open import Core.Derivations as C renaming (_⊢_⦂_ to _⊢ᶜ_⦂_)
open import Core.Derivations.Lemmas
open import Core.Operational as C
open import Core.Operational.BetaEquivalence as C
open import Surface.Syntax as S renaming (Γ to Γˢ; τ to τˢ; ε to εˢ)
open import Surface.Syntax.Membership as S renaming (_∈_at_ to _∈ˢ_at_)
open import Surface.Derivations as S
open import Surface.Theorems.Agreement

open import Translation.Untyped
open import Translation.Typed
open import Translation.μ-weakening

μ-Τ-well-typed : Γᶜ ⊢ᶜ ⋆ₑ ⦂ □ₑ
               → Γᶜ ⊢ᶜ ⌊μ⌋-Τ ⦂ ⋆ₑ
μ-Τ-well-typed δ = ≡̂-well-typed (CT-UnitTerm δ) (CT-UnitTerm δ) (CT-UnitType δ)

μ-b-well-typed : Γᶜ ⊢ᶜ ⋆ₑ ⦂ □ₑ
               → Γᶜ ⊢ᶜ ⌊μ⌋-b b ⦂ ⋆ₑ
μ-b-well-typed {b = BUnit} Γᶜok =
  Σ-well-typed
    Γ⊢CUnit
    (CT-Abs
      (μ-Τ-well-typed Γ,CUnit-ok)
      (CT-Form Γ⊢CUnit Γ,CUnit-ok)
    )
  where
  Γ⊢CUnit = CT-UnitType Γᶜok
  Γ,CUnit-ok = Γ⊢τ-⇒-Γ,τ-ok Γ⊢CUnit

⊢ᶜ-subst₁-CT-Sort : ∀ Γˢ
                  → ∀ {Γᶜ₂}
                  → (Γok₁ Γok₂ : Γˢ ok[ E ])
                  → ⊘ ≡ μ-Γ Γok₁
                  → Γᶜ₂ ≡ μ-Γ Γok₂
                  → Γᶜ₂ ⊢ᶜ ⋆ₑ ⦂ □ₑ
⊢ᶜ-subst₁-CT-Sort ⊘ TCTX-Empty TCTX-Empty _ refl = CT-Sort

⊢ᶜ-subst₁ : ∀ {Γᶜ₁ Γᶜ₂}
          → (Γok₁ Γok₂ : Γˢ ok[ E ])
          → Γᶜ₁ ⊢ᶜ εᶜ ⦂ τ
          → Γᶜ₁ ≡ μ-Γ Γok₁
          → Γᶜ₂ ≡ μ-Γ Γok₂
          → Γᶜ₂ ⊢ᶜ εᶜ ⦂ τ
⊢ᶜ-subst₁ Γok₁ Γok₂ CT-Sort ≡₁ ≡₂ = ⊢ᶜ-subst₁-CT-Sort _ Γok₁ Γok₂ ≡₁ ≡₂
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-Var {τ = τ} δ) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-Weaken δ δ₁) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-Form δ δ₁) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-App δ δ₁) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-Abs δ δ₁) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-Conv δ δ₁ x) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-UnitType δ) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-UnitTerm δ) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-ADTForm consδs) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-ADTCon ≡-prf δ δ₁) ≡₁ ≡₂ = {! !}
⊢ᶜ-subst₁ Γok₁ Γok₂ (CT-ADTCase δ δ₁ branches) ≡₁ ≡₂ = {! !}

μ-preserves-∈ : (Γok : Γˢ ok[ E ])
              → (∈ : τˢ ∈ˢ Γˢ at ι)
              → μ-τ (τ∈Γ-⇒-Γ⊢τ Γok ∈) ∈ᶜ μ-Γ Γok at ι
μ-preserves-∈ (TCTX-Bind Γok τδ) (∈-zero refl) = ∈-zero (μ-τ-weakening-commutes Γok τδ τδ)
μ-preserves-∈ (TCTX-Bind Γok τδ) (∈-suc refl ∈) = ∈-suc (μ-τ-weakening-commutes Γok τδ (τ∈Γ-⇒-Γ⊢τ Γok ∈)) (μ-preserves-∈ Γok ∈)

mutual
  μ-Γ-well-typed : (Γok : Γˢ ok[ E ])
                 → μ-Γ Γok ⊢ᶜ ⋆ₑ ⦂ □ₑ
  μ-Γ-well-typed TCTX-Empty = CT-Sort
  μ-Γ-well-typed (TCTX-Bind Γok τδ) = CT-Weaken (μ-Γ-well-typed Γok) (⊢ᶜ-subst₁ (Γ⊢τ-⇒-Γok τδ) Γok (μ-τ-well-typed τδ) refl refl)

  μ-b-P-well-typed : Γᶜ ⊢ᶜ ⋆ₑ ⦂ □ₑ
                   → Γᶜ ⊢ᶜ CΠ (⌊μ⌋-b b) ⋆ₑ ⦂ □ₑ
  μ-b-P-well-typed Γᶜok
    = let μ-b-ok = μ-b-well-typed Γᶜok
       in CT-Form
            μ-b-ok
            (Γ⊢τ-⇒-Γ,τ-ok μ-b-ok)

  μ-τ-well-typed : (τδ : Γˢ ⊢[ E ] τˢ)
                 → μ-Γ (Γ⊢τ-⇒-Γok τδ) ⊢ᶜ μ-τ τδ ⦂ ⋆ₑ
  μ-τ-well-typed δ = {! !}

  μ-ε-well-typed : (εδ : Γˢ ⊢[ E ] εˢ ⦂ τˢ)
                 → μ-Γ (Γ⊢ε⦂τ-⇒-Γok εδ) ⊢ᶜ μ-ε εδ ⦂ μ-τ (Γ⊢ε⦂τ-⇒-Γ⊢τ εδ)
  μ-ε-well-typed (T-Unit Γok) = {! !}
  μ-ε-well-typed (T-Var Γok ∈) = CT-VarW {! μ-τ-well-typed (τ∈Γ-⇒-Γ⊢τ Γok ∈) !} (μ-preserves-∈ Γok ∈)
  μ-ε-well-typed (T-Abs arrδ δ) = {! !}
  μ-ε-well-typed (T-App δ δ₁) = {! !}
  μ-ε-well-typed (T-Case resδ δ branches-well-typed) = {! !}
  μ-ε-well-typed (T-Con ≡-prf δ adtτ) = {! !}
  μ-ε-well-typed (T-Sub δ τ'δ <:) = {! !}

                 {-
  μ-τ-well-typed : (Γok : Γˢ ok[ E ])
                 → (τδ : Γˢ ⊢[ E ] τˢ)
                 → μ-Γ Γok ⊢ᶜ μ-τ τδ ⦂ ⋆ₑ
  μ-τ-well-typed Γok (TWF-TrueRef _) = μ-b-well-typed (μ-Γ-well-typed Γok)
  μ-τ-well-typed Γok (TWF-Base ε₁δ ε₂δ) =
    Σ-well-typed
      (μ-b-well-typed Γ̂ok)
      (CT-Abs
        (≡̂-well-typed ε̂₁δ ε̂₂δ (μ-b-well-typed (CT-Weaken Γ̂ok (μ-b-well-typed Γ̂ok))))
        (μ-b-P-well-typed Γ̂ok)
      )
    where
    Γ̂ok = μ-Γ-well-typed Γok
    Γ,⟨b∣Τ⟩ok = TCTX-Bind Γok (TWF-TrueRef Γok)
    ε̂₁δ = {! !} -- μ-ε-well-typed Γ,⟨b∣Τ⟩ok (TWF-TrueRef (TCTX-Bind Γok _)) ε₁δ
    ε̂₂δ = {! !} -- μ-ε-well-typed Γ,⟨b∣Τ⟩ok (TWF-TrueRef (TCTX-Bind Γok _)) ε₂δ
  μ-τ-well-typed Γok (TWF-Conj τδ₁ τδ₂) = ×-well-typed (μ-τ-well-typed Γok τδ₁) (μ-τ-well-typed Γok τδ₂)
  μ-τ-well-typed Γok (TWF-Arr τδ₁ τδ₂) = CT-Form (μ-τ-well-typed Γok τδ₁) {! !} -- (μ-τ-well-typed (TCTX-Bind Γok τδ₁) τδ₂)
  μ-τ-well-typed Γok (TWF-ADT consδs) = CT-ADTForm {! !} -- (μ-cons-well-typed Γok consδs)
  -}

  {-
  μ-cons-well-typed : {cons : S.ADTCons nₐ ℓ}
                    → (Γok : Γˢ ok[ E ])
                    → (δs : All (Γˢ ⊢[ E ]_) cons)
                    → All (λ con → μ-Γ Γok ⊢ᶜ con ⦂ ⋆ₑ) (μ-cons δs)
  μ-cons-well-typed Γok [] = []
  μ-cons-well-typed Γok (τδ ∷ δs) = μ-τ-well-typed Γok τδ ∷ μ-cons-well-typed Γok δs

  μ-ε-well-typed : (Γok : Γˢ ok[ E ])
                 → (τδ : Γˢ ⊢[ E ] τˢ)
                 → (εδ : Γˢ ⊢[ E ] εˢ ⦂ τˢ)
                 → μ-Γ Γok ⊢ᶜ μ-ε εδ ⦂ μ-τ τδ
  μ-ε-well-typed Γok τδ (T-Unit _) = {!  !}
  μ-ε-well-typed Γok τδ (T-Var _ ∈) = CT-VarW (μ-τ-well-typed Γok τδ) {! !} -- (μ-preserves-∈ τδ Γok ∈)
  μ-ε-well-typed Γok τδ (T-Abs arrδ εδ) = {! !}
  μ-ε-well-typed Γok τδ (T-App δ₁ δ₂) = {! !}
  μ-ε-well-typed Γok τδ (T-Case resδ δ branches-well-typed) = {! !}
  μ-ε-well-typed Γok τδ (T-Con refl δ adtτ) = {! !}
  μ-ε-well-typed Γok τδ (T-Sub δ τ'δ <:) = {! !}
  -}
