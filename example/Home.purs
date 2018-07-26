module Example.Home where

import Prelude

import Data.Maybe (Maybe(..))
import Effect.Aff (Aff)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Properties as HP
import Ocelot.Block.Format as Format
import Ocelot.HTML.Properties (css)

-----
-- Render

render :: ∀ m. H.ComponentHTML Box () m
render =
  HH.div
  [ css "flex-1 container p-12" ]
  [ Format.heading_
    [ HH.text "Formless" ]
  , Format.subHeading_
    [ HH.text "A renderless component for painless forms in Halogen" ]
  , Format.p_
    [ HH.text $
      "Formless allows you to write a small, simple spec for your form and receive "
      <> "state updates, validation, dirty states, submission handling, and more for "
      <> "free. You are responsible for providing an initial value and a validation "
      <> "function for every field in your form, but beyond that, Formless will take "
      <> "care of things behind the scenes without ever imposing on how you'd like to "
      <> "render and display your form. You can freely use external Halogen components, "
      <> "add new form behaviors on top (like dependent validation or clearing sets of "
      <> "fields), and more."
      <> "\n"
    ]
  , HH.a
    [ HP.classes Format.linkClasses
    , HP.href "https://github.com/thomashoneyman/purescript-halogen-formless"
    ]
    [ HH.text "purescript-halogen-formless" ]
  ]

-----
-- Component

data Box a = Box a

component :: H.Component HH.HTML Box Unit Void Aff
component = H.component
  { initialState: const unit
  , render: const render
  , eval
  , receiver: const Nothing
  , initializer: Nothing
  , finalizer: Nothing
  }

  where

  eval :: Box ~> H.HalogenM Unit Box () Void Aff
  eval (Box a) = pure a
