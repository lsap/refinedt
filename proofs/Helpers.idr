module Helpers

import Data.List

%default total
%access public export

data Sublist : (sub : List a) -> (ls : List a) -> Type where
  EmptyIsSublist  : Sublist [] ls
  IgnoreHead      : (rest : Sublist sub ls) -> Sublist sub (_ :: ls)
  AppendBoth      : (rest : Sublist sub ls) -> Sublist (x :: sub) (x :: ls)

sublistSelf : (ls : List a) -> Sublist ls ls
sublistSelf [] = EmptyIsSublist
sublistSelf (_ :: xs) = AppendBoth $ sublistSelf xs

superListHasElems : Sublist sub super -> Elem x sub -> Elem x super
superListHasElems (IgnoreHead rest) elemPrf = There (superListHasElems rest elemPrf)
superListHasElems (AppendBoth _) Here = Here
superListHasElems (AppendBoth rest) (There later) = There (superListHasElems rest later)
