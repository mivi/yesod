{-# LANGUAGE OverloadedStrings #-}
import Test.Hspec.Monadic
import Test.Hspec.HUnit ()
import Test.HUnit ((@?=))
import Data.Text (Text, unpack)
import Yesod.Routes

data Dummy = Dummy

result :: ([Text] -> Maybe Int) -> Dispatch sub master Int
result f _ _ ts _ _ = f ts

justRoot :: Dispatch Dummy Dummy Int
justRoot = toDispatch
    [ RouteHandler [] False $ result $ const $ Just 1
    ]

twoStatics :: Dispatch Dummy Dummy Int
twoStatics = toDispatch
    [ RouteHandler [StaticPiece "foo"] False $ result $ const $ Just 2
    , RouteHandler [StaticPiece "bar"] False $ result $ const $ Just 3
    ]

multi :: Dispatch Dummy Dummy Int
multi = toDispatch
    [ RouteHandler [StaticPiece "foo"] False $ result $ const $ Just 4
    , RouteHandler [StaticPiece "bar"] True $ result $ const $ Just 5
    ]

dynamic :: Dispatch Dummy Dummy Int
dynamic = toDispatch
    [ RouteHandler [StaticPiece "foo"] False $ result $ const $ Just 6
    , RouteHandler [SinglePiece] False $ result $ \ts ->
        case ts of
            [t] ->
                case reads $ unpack t of
                    [] -> Nothing
                    (i, _):_ -> Just i
            _ -> error $ "Called dynamic with: " ++ show ts
    ]

overlap :: Dispatch Dummy Dummy Int
overlap = toDispatch
    [ RouteHandler [StaticPiece "foo"] False $ result $ const $ Just 20
    , RouteHandler [StaticPiece "foo"] True $ result $ const $ Just 21
    , RouteHandler [] True $ result $ const $ Just 22
    ]

test :: Dispatch Dummy Dummy Int -> [Text] -> Maybe Int
test dispatch ts = dispatch Dummy Nothing ts Dummy id

main :: IO ()
main = hspecX $ do
    describe "justRoot" $ do
        it "dispatches correctly" $ test justRoot [] @?= Just 1
        it "fails correctly" $ test justRoot ["foo"] @?= Nothing
    describe "twoStatics" $ do
        it "dispatches correctly to foo" $ test twoStatics ["foo"] @?= Just 2
        it "dispatches correctly to bar" $ test twoStatics ["bar"] @?= Just 3
        it "fails correctly (1)" $ test twoStatics [] @?= Nothing
        it "fails correctly (2)" $ test twoStatics ["bar", "baz"] @?= Nothing
    describe "multi" $ do
        it "dispatches correctly to foo" $ test multi ["foo"] @?= Just 4
        it "dispatches correctly to bar" $ test multi ["bar"] @?= Just 5
        it "dispatches correctly to bar/baz" $ test multi ["bar", "baz"] @?= Just 5
        it "fails correctly (1)" $ test multi [] @?= Nothing
        it "fails correctly (2)" $ test multi ["foo", "baz"] @?= Nothing
    describe "dynamic" $ do
        it "dispatches correctly to foo" $ test dynamic ["foo"] @?= Just 6
        it "dispatches correctly to 7" $ test dynamic ["7"] @?= Just 7
        it "dispatches correctly to 42" $ test dynamic ["42"] @?= Just 42
        it "fails correctly on five" $ test dynamic ["five"] @?= Nothing
        it "fails correctly on too many" $ test dynamic ["foo", "baz"] @?= Nothing
        it "fails correctly on too few" $ test dynamic [] @?= Nothing
    describe "overlap" $ do
        it "dispatches correctly to foo" $ test overlap ["foo"] @?= Just 20
        it "dispatches correctly to foo/bar" $ test overlap ["foo", "bar"] @?= Just 21
        it "dispatches correctly to bar" $ test overlap ["bar"] @?= Just 22
        it "dispatches correctly to []" $ test overlap [] @?= Just 22