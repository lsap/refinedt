{-# LANGUAGE OverloadedStrings #-}

module T10DefsParserSpec(spec) where

import Test.Hspec

import Toy.Language.Parser.Decl
import Toy.Language.Syntax.Decl

import TestUtils

spec :: Spec
spec = do
  describe "Parsing basic fundefs" $ let p = parse' funDef in do
    it "parses identity function" $ p "id x = x" ~~> FunDef "id" ["x"] (TName "x")
    it "parses application" $ p "dot x y = x y" ~~> FunDef "dot" ["x", "y"] (TName "x" `TApp` TName "y")
