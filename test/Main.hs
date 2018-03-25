{-# LANGUAGE OverloadedStrings #-}

-- | Simple test suite.

module Main where

import           Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.UTF8 as UTF8
import           Test.Hspec
import           Xeno.SAX
import           Xeno.DOM
import           Xeno.Types

main :: IO ()
main = hspec spec

spec :: SpecWith ()
spec =
  describe
    "hexml tests"
    (do mapM_
          (\(v, i) -> it (show i) (shouldBe (Xeno.SAX.validate i) v))
          (hexml_examples_sax  ++ extra_examples_sax)
        mapM_
          (\(v, i) -> it (show i) (shouldBe (either (Left . show) (Right . id) (contents <$> Xeno.DOM.parse i)) v))
          cdata_tests
        let doc =
              parse
                "<root><test id=\"1\" extra=\"2\" />\n<test id=\"2\" /><b><test id=\"3\" /></b><test id=\"4\" /><test /></root>"
        it
          "children test"
          (shouldBe
             (map name (children $ fromRightE doc))
             ["test", "test", "b", "test", "test"])
        it
          "attributes"
          (shouldBe
             (attributes (head (children $ fromRightE doc)))
             [("id", "1"), ("extra", "2")])

        it "xml prologue test" $ do
          let docWithPrologue = "<?xml version=\"1.1\"?>\n<greeting>Hello, world!</greeting>"
              parsedRoot = fromRightE $ Xeno.DOM.parse docWithPrologue
          name parsedRoot `shouldBe` "greeting"

        it "DOM from bytestring substring" $ do
          let substr = BS.drop 5 "5<8& <valid>xml<here/></valid>"
              parsedRoot = fromRightE $ Xeno.DOM.parse substr
          name parsedRoot `shouldBe` "valid"

        -- If this works without crashing we're happy.
        let nsdoc = "<ns:tag os:attr=\"Namespaced attribute value\">Content.</ns:tag>"
        it
          "namespaces"
          (shouldBe
             (Xeno.SAX.validate nsdoc)
             True)
    )

hexml_examples_sax :: [(Bool, ByteString)]
hexml_examples_sax =
    [(True, "<test id='bob'>here<extra/>there</test>")
    ,(True, "<test /><close />")
    ,(True, "<test /><!-- comment > --><close />")
    ,(True, "<test id=\"bob value\" another-attr=\"test with <\">here </test> more text at the end<close />")
    ,(True, "<test></more>") -- SAX doesn't care about tag balancing
    ,(False, "<test")
    ,(True, "<?xml version=\"1.1\"?>\n<greeting>Hello, world!</greeting>")
    ]

extra_examples_sax :: [(Bool, ByteString)]
extra_examples_sax =
    [(True, "<some-example/>")
    ,(True, "<a numeric1=\"attribute\"/>")
    ,(True, "<also.a.dot></also.a.dot>")
    ,(True, UTF8.fromString "<Åmål/>")
    ]

-- | We want to make sure that the parser doesn't jump out of the CDATA
-- area prematurely because it encounters a single ].
cdata_tests :: [(Either a [Content], ByteString)]
cdata_tests =
    [ ( Right [CData "Oneliner CDATA."]
      , "<test><![CDATA[Oneliner CDATA.]]></test>")
    , ( Right [CData "<strong>This is strong but not XML tags.</strong>"]
      , "<test><![CDATA[<strong>This is strong but not XML tags.</strong>]]></test>")
    , ( Right [CData "A lonely ], sad isn't it?"]
      , "<test><![CDATA[A lonely ], sad isn't it?]]></test>")
    ]

-- | Horrible hack. Don't try this at home.
fromRightE :: Either XenoException a -> a
fromRightE = either (error. show) id
