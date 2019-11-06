module Test.Toml.BiCode.Property where

import Control.Applicative (liftA2, (<|>))
import Control.Category ((>>>))
import Data.ByteString (ByteString)
import Data.HashSet (HashSet)
import Data.IntSet (IntSet)
import Data.List.NonEmpty (NonEmpty)
import Data.Map.Strict (Map)
import Data.Monoid (All (..), Any (..), First (..), Last (..), Product (..), Sum (..))
import Data.Set (Set)
import Data.Text (Text)
import Data.Time (Day, LocalTime, TimeOfDay, ZonedTime, zonedTimeToUTC)
import GHC.Exts (fromList)
import Hedgehog (Gen, forAll, tripping)
import Numeric.Natural (Natural)

import Toml (TomlBiMap, TomlCodec, (.=))
import Toml.Bi.Code (decode, encode)

import Test.Toml.Gen (PropertyTest, genBool, genByteString, genDay, genDouble, genFloat, genHashSet,
                      genHours, genInt, genIntSet, genInteger, genLByteString, genLocal, genNatural,
                      genNonEmpty, genString, genText, genWord, genZoned, prop)

import qualified Data.ByteString.Lazy as L
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import qualified Toml


test_encodeDecodeProp :: PropertyTest
test_encodeDecodeProp = prop "decode . encode == id" $ do
    bigType <- forAll genBigType
    tripping bigType (encode bigTypeCodec) (decode bigTypeCodec)

data BigType = BigType
    { btBool          :: !Bool
    , btInteger       :: !Integer
    , btNatural       :: !Natural
    , btInt           :: !Int
    , btWord          :: !Word
    , btDouble        :: !(Batman Double)
    , btFloat         :: !(Batman Float)
    , btText          :: !Text
    , btString        :: !String
    , btBS            :: !ByteString
    , btLazyBS        :: !L.ByteString
    , btLocalTime     :: !LocalTime
    , btDay           :: !Day
    , btTimeOfDay     :: !TimeOfDay
    , btArray         :: ![Int]
    , btArraySet      :: !(Set Word)
    , btArrayIntSet   :: !IntSet
    , btArrayHashSet  :: !(HashSet Natural)
    , btArrayNonEmpty :: !(NonEmpty Text)
    , btNonEmpty      :: !(NonEmpty ByteString)
    , btList          :: ![Bool]
    , btNewtype       :: !BigTypeNewtype
    , btSumType       :: !BigTypeSum
    , btRecord        :: !BigTypeRecord
    , btMap           :: !(Map Int Bool)
    , btAll           :: !All
    , btAny           :: !Any
    , btSum           :: !(Sum Int)
    , btProduct       :: !(Product Int)
    , btFirst         :: !(First Int)
    , btLast          :: !(Last Int)
    } deriving stock (Show, Eq)

-- | Wrapper over 'Double' and 'Float' to be equal on @NaN@ values.
newtype Batman a = Batman
    { unBatman :: a
    } deriving stock (Show)

instance RealFloat a => Eq (Batman a) where
    Batman a == Batman b =
        if isNaN a
            then isNaN b
            else a == b

newtype BigTypeNewtype = BigTypeNewtype
    { unBigTypeNewtype :: ZonedTime
    } deriving stock (Show)

instance Eq BigTypeNewtype where
    (BigTypeNewtype a) == (BigTypeNewtype b) = zonedTimeToUTC a == zonedTimeToUTC b

data BigTypeSum
    = BigTypeSumA !Integer
    | BigTypeSumB !Text
    deriving stock (Show, Eq)

data BigTypeRecord = BigTypeRecord
    { btrBoolSet     :: !(Set Bool)
    , btrNewtypeList :: ![BigTypeSum]
    } deriving stock (Show, Eq)

bigTypeCodec :: TomlCodec BigType
bigTypeCodec = BigType
    <$> Toml.bool                            "bool"                .= btBool
    <*> Toml.integer                         "integer"             .= btInteger
    <*> Toml.natural                         "natural"             .= btNatural
    <*> Toml.int                             "int"                 .= btInt
    <*> Toml.word                            "word"                .= btWord
    <*> Toml.diwrap (Toml.double "double")                         .= btDouble
    <*> Toml.diwrap (Toml.float "float")                           .= btFloat
    <*> Toml.text                            "text"                .= btText
    <*> Toml.string                          "string"              .= btString
    <*> Toml.byteString                      "bs"                  .= btBS
    <*> Toml.lazyByteString                  "lbs"                 .= btLazyBS
    <*> Toml.localTime                       "localTime"           .= btLocalTime
    <*> Toml.day                             "day"                 .= btDay
    <*> Toml.timeOfDay                       "timeOfDay"           .= btTimeOfDay
    <*> Toml.arrayOf Toml._Int               "arrayOfInt"          .= btArray
    <*> Toml.arraySetOf Toml._Word           "arraySetOfWord"      .= btArraySet
    <*> Toml.arrayIntSet                     "arrayIntSet"         .= btArrayIntSet
    <*> Toml.arrayHashSetOf Toml._Natural    "arrayHashSetDouble"  .= btArrayHashSet
    <*> Toml.arrayNonEmptyOf Toml._Text      "arrayNonEmptyOfText" .= btArrayNonEmpty
    <*> Toml.nonEmpty (Toml.byteString "bs") "nonEmptyBS"          .= btNonEmpty
    <*> Toml.list (Toml.bool "bool")         "listBool"            .= btList
    <*> Toml.diwrap (Toml.zonedTime "nt.zonedTime")                .= btNewtype
    <*> bigTypeSumCodec                                            .= btSumType
    <*> Toml.table bigTypeRecordCodec        "table-record"        .= btRecord
    <*> Toml.map (Toml.int "key") (Toml.bool "val") "map"          .= btMap
    <*> Toml.all                             "all"                 .= btAll
    <*> Toml.any                             "any"                 .= btAny
    <*> Toml.sum Toml.int                    "sum"                 .= btSum
    <*> Toml.product Toml.int                "product"             .= btProduct
    <*> Toml.first Toml.int                  "first"               .= btFirst
    <*> Toml.last Toml.int                   "last"                .= btLast

_BigTypeSumA :: TomlBiMap BigTypeSum Integer
_BigTypeSumA = Toml.prism BigTypeSumA $ \case
    BigTypeSumA i -> Right i
    other   -> Toml.wrongConstructor "BigTypeSumA" other

_BigTypeSumB :: TomlBiMap BigTypeSum Text
_BigTypeSumB = Toml.prism BigTypeSumB $ \case
    BigTypeSumB n -> Right n
    other    -> Toml.wrongConstructor "BigTypeSumB" other

bigTypeSumCodec :: TomlCodec BigTypeSum
bigTypeSumCodec =
        Toml.match (_BigTypeSumA >>> Toml._Integer) "sum.integer"
    <|> Toml.match (_BigTypeSumB >>> Toml._Text)    "sum.text"

bigTypeRecordCodec :: TomlCodec BigTypeRecord
bigTypeRecordCodec = BigTypeRecord
    <$> Toml.arraySetOf Toml._Bool "rboolSet" .= btrBoolSet
    <*> Toml.list bigTypeSumCodec "rnewtype" .= btrNewtypeList

----------------------------------------------------------------------------
-- Generator
----------------------------------------------------------------------------

genBigType :: Gen BigType
genBigType = do
    btBool          <- genBool
    btInteger       <- genInteger
    btNatural       <- genNatural
    btInt           <- genInt
    btWord          <- genWord
    btDouble        <- Batman <$> genDouble
    btFloat         <- Batman <$> genFloat
    btText          <- genText
    btString        <- genString
    btBS            <- genByteString
    btLazyBS        <- genLByteString
    btLocalTime     <- genLocal
    btDay           <- genDay
    btTimeOfDay     <- genHours
    btArray         <- Gen.list (Range.constant 0 5) genInt
    btArraySet      <- Gen.set (Range.constant 0 5) genWord
    btArrayIntSet   <- genIntSet
    btArrayHashSet  <- genHashSet genNatural
    btArrayNonEmpty <- genNonEmpty genText
    btNonEmpty      <- genNonEmpty genByteString
    btList          <- Gen.list (Range.constant 0 5) genBool
    btNewtype       <- genNewType
    btSumType       <- genSum
    btRecord        <- genRec
    btMap           <- Gen.map (Range.constant 0 10) (liftA2 (,) genInt genBool)
    btAll           <- All <$> genBool
    btAny           <- Any <$> genBool
    btSum           <- Sum <$> genInt
    btProduct       <- Product <$> genInt
    btFirst         <- First <$> Gen.maybe genInt
    btLast          <- Last <$> Gen.maybe genInt
    pure BigType {..}

-- Custom generators

genNewType :: Gen BigTypeNewtype
genNewType = BigTypeNewtype <$> genZoned

genSum :: Gen BigTypeSum
genSum = Gen.choice
    [ BigTypeSumA <$> genInteger
    , BigTypeSumB <$> genText
    ]

genRec :: Gen BigTypeRecord
genRec = do
    btrBoolSet <- fromList <$> Gen.list (Range.constant 0 5) genBool
    btrNewtypeList <- Gen.list (Range.constant 0 5) genSum
    pure BigTypeRecord{..}
