{-# OPTIONS --safe #-}

module Surface.Derivations.Algorithmic.Theorems where

open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import Surface.Syntax
open import Surface.Syntax.Membership
open import Surface.Derivations.Algorithmic

Unique : ∀ A → Set
Unique Deriv = ∀ (δ₁ δ₂ : Deriv)
               → δ₁ ≡ δ₂

mutual
  unique-Γok : Unique (Γ ok[ φ ])
  unique-Γok TCTX-Empty TCTX-Empty = refl
  unique-Γok (TCTX-Bind δ₁ τδ₁) (TCTX-Bind δ₂ τδ₂)
    rewrite unique-Γok δ₁ δ₂
          | unique-Γ⊢τ τδ₁ τδ₂
          = refl

  unique-Γ⊢τ : Unique (Γ ⊢[ φ ] τ)
  unique-Γ⊢τ (TWF-TrueRef Γok₁) (TWF-TrueRef Γok₂)
    rewrite unique-Γok Γok₁ Γok₂
          = refl
  unique-Γ⊢τ (TWF-Base ε₁δ₁ ε₂δ₁) (TWF-Base ε₁δ₂ ε₂δ₂)
    rewrite unique-Γ⊢ε⦂τ ε₁δ₁ ε₁δ₂
          | unique-Γ⊢ε⦂τ ε₂δ₁ ε₂δ₂
          = refl
  unique-Γ⊢τ (TWF-Conj δ₁₁ δ₂₁) (TWF-Conj δ₁₂ δ₂₂)
    rewrite unique-Γ⊢τ δ₁₁ δ₁₂
          | unique-Γ⊢τ δ₂₁ δ₂₂
          = refl
  unique-Γ⊢τ (TWF-Arr δ₁₁ δ₂₁) (TWF-Arr δ₁₂ δ₂₂)
    rewrite unique-Γ⊢τ δ₁₁ δ₁₂
          | unique-Γ⊢τ δ₂₁ δ₂₂
          = refl
  unique-Γ⊢τ (TWF-ADT consδs₁) (TWF-ADT consδs₂) = {! !}

  unique-Γ⊢ε⦂τ : Unique (Γ ⊢[ φ ] ε ⦂ τ)
  unique-Γ⊢ε⦂τ (T-Unit Γok₁) (T-Unit Γok₂)
    rewrite unique-Γok Γok₁ Γok₂
          = refl
  unique-Γ⊢ε⦂τ (T-Var Γok₁ ∈₁) (T-Var Γok₂ ∈₂)
    rewrite unique-Γok Γok₁ Γok₂
          = {! !}
  unique-Γ⊢ε⦂τ (T-Abs arrδ₁ δ₁) (T-Abs arrδ₂ δ₂) = {! !}
  unique-Γ⊢ε⦂τ (T-App δ₁₁ δ₂₁ <:₁ resτδ₁) δ₂ = {! δ₂ !}
  unique-Γ⊢ε⦂τ (T-Case resδ₁ δ₁ bsδ₁) (T-Case resδ² δ₂ bsδ₂) = {! !}
  unique-Γ⊢ε⦂τ (T-Con refl δ₁ adtτ₁) (T-Con refl δ₂ adtτ₂) = {! !}
