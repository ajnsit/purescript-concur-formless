module Example.RealWorld.Render.Field where

import Prelude

import Data.Either (Either)
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Newtype (class Newtype, unwrap)
import Data.String (toLower) as String
import Data.Symbol (class IsSymbol, SProxy)
import Example.Validation.Utils (showError)
import Formless as Formless
import Formless.Spec (InputField)
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Ocelot.Block.FormField as FormField
import Ocelot.Block.Input as Input
import Prim.Row (class Cons)
import Record as Record

-----
-- Types

type FieldConfig sym =
  { label :: String
  , helpText :: String
  , placeholder :: Maybe String
  , field :: SProxy sym
  }

-----
-- Common field rendering

data FieldType
  = Currency
  | Percentage
  | Text

input
  :: ∀ form sym e o t0 fields m pq cq cs
   . IsSymbol sym
  => Show e
  => Newtype (form InputField) (Record fields)
  => Cons sym (InputField String e o) t0 fields
  => FieldConfig sym
  -> FieldType
  -> Formless.State form m
  -> Formless.HTML pq cq cs form m
input config ft state =
  HH.div_
    [ formField state config $ \field ->
        case ft of
          Text -> Input.input (props field)
          Currency -> Input.currency_ (props field)
          Percentage -> Input.percentage_ (props field)
    ]
  where
    props field =
      [ HP.placeholder $ fromMaybe "" config.placeholder
      , HP.value field.input
      , Formless.onBlurWith config.field
      , Formless.onValueInputWith config.field
      ]


-- | A utility to help create form fields using an unwrapped
-- | field value from a given symbol.
formField
  :: ∀ form sym i e o t0 fields m pq cq cs
   . IsSymbol sym
  => Show e
  => Newtype (form InputField) (Record fields)
  => Cons sym (InputField i e o) t0 fields
  => Formless.State form m
  -> FieldConfig sym
  -> ( { result :: Maybe (Either e o)
       , touched :: Boolean
       , input :: i
       }
       -> Formless.HTML pq cq cs form m
     )
  -> Formless.HTML pq cq cs form m
formField state config html =
  HH.div_
    [ FormField.field_
        { label: config.label
        , helpText: Just config.helpText
        , error: showError field
        , inputId: String.toLower config.label
        }
        [ html field ]
    ]
  where
    field = unwrap $ Record.get config.field $ unwrap state.form
