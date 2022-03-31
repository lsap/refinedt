{-# OPTIONS --safe #-}

module Translation.SubstUnique where

open import Relation.Binary.PropositionalEquality using (subst; cong)

open import Core.Syntax as C renaming (Γ to Γᶜ; ε to εᶜ; τ to τᶜ)
open import Core.Derivations as C renaming (_⊢_⦂_ to _⊢ᶜ_⦂_)
open import Intermediate.Syntax as I renaming (Γ to Γⁱ; τ to τⁱ; τ' to τ'ⁱ; ε to εⁱ)
open import Intermediate.Derivations.Algorithmic as I
open import Intermediate.Derivations.Algorithmic.Theorems.Uniqueness

open import Translation.Typed

subst-Γ : (Γok₁ Γok₂ : [ θ ] Γⁱ ok)
        → μ-Γ Γok₁ ⊢ᶜ εᶜ ⦂ τᶜ
        → μ-Γ Γok₂ ⊢ᶜ εᶜ ⦂ τᶜ
subst-Γ _ _ = subst (_⊢ᶜ _ ⦂ _) (cong μ-Γ (unique-Γok _ _))

subst-τ : (Γ⊢τ₁ Γ⊢τ₂ : [ θ ] Γⁱ ⊢ τⁱ)
        → Γᶜ ⊢ᶜ εᶜ ⦂ μ-τ Γ⊢τ₁
        → Γᶜ ⊢ᶜ εᶜ ⦂ μ-τ Γ⊢τ₂
subst-τ Γ⊢τ₁ Γ⊢τ₂ = subst (_ ⊢ᶜ _ ⦂_) (cong μ-τ (unique-Γ⊢τ Γ⊢τ₁ Γ⊢τ₂))
