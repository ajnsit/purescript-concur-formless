module Example.RealWorld.Component where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Newtype (over)
import Effect.Aff (Aff)
import Effect.Console as Console
import Example.RealWorld.Data.Group (Group(..), _admin, _applications, _pixels, _secretKey1, _secretKey2, _whiskey)
import Example.RealWorld.Data.Options (Options(..), _metric)
import Example.RealWorld.Render.GroupForm as GroupForm
import Example.RealWorld.Render.Nav as Nav
import Example.RealWorld.Render.OptionsForm as OptionsForm
import Example.RealWorld.Spec.GroupForm (groupFormSpec, groupFormSubmit, groupFormValidate)
import Example.RealWorld.Spec.OptionsForm (optionsFormSpec, optionsFormValidate)
import Example.RealWorld.Types (GroupTASlot(..), Query(..), Slots, State, Tab(..), _dropdown, _groupForm, _optionsForm, _typeahead)
import Formless as Formless
import Formless.Spec.Transform (unwrapOutput)
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Ocelot.Block.Format as Format
import Ocelot.Components.Dropdown as Dropdown
import Ocelot.Components.Typeahead as TA
import Ocelot.HTML.Properties (css)

component :: H.Component HH.HTML Query Unit Void Aff
component =
  H.component
    { initialState: const initialState
    , render
    , eval
    , receiver: const Nothing
    , initializer: Nothing
    , finalizer: Nothing
    }
  where

  initialState :: State
  initialState =
    { focus: GroupFormTab
    , groupFormErrors: 0
    , groupFormDirty: false
    , optionsFormErrors: 0
    , optionsFormDirty: false
    , group: Nothing
    }

  render :: State -> H.ComponentHTML Query Slots Aff
  render st =
    HH.div
    [ css "p-12 w-full container" ]
    [ Format.heading_
      [ HH.text "Formless" ]
    , Format.subHeading_
      [ HH.text "A complex form inspired by real-world use cases." ]
    , Format.p_
      [ HH.text $
        "This component demonstrates building a large form with complex rendering and validation "
        <> "requirements. Notice how both tabs end up unifying to a single output type after the "
        <> "two forms are combined, how various dropdowns determine the contents (and visibility) "
        <> "of other form elements, the assorted external components, and how validation for many "
        <> "fields depends on the values of other fields in the form."
      ]
    , Format.p_
      [ HH.text $
        "Next, review the source code. You'll notice that all of the complex types and state necessary "
        <> "to run this form can be generated from a pair of row types. All that's left for you to handle "
        <> "is to write the validation (with helper functions) and the render function."
      ]
    , Nav.tabs st
    , HH.div
      [ if st.focus == GroupFormTab then css "" else css "hidden" ]
      [ HH.slot
          _groupForm
          unit
          Formless.component
          { formSpec: groupFormSpec
          , validator: groupFormValidate
          , submitter: groupFormSubmit
          , render: GroupForm.render
          }
          (HE.input HandleGroupForm)
      ]
    , HH.div
      [ if st.focus == OptionsFormTab then css "" else css "hidden" ]
      [ HH.slot
          _optionsForm
          unit
          Formless.component
          { formSpec: optionsFormSpec
          , validator: pure <$> optionsFormValidate
          , submitter: pure <<< Options <<< unwrapOutput
          , render: OptionsForm.render
          }
          (HE.input HandleOptionsForm)
      ]
    ]

  eval :: Query ~> H.HalogenM State Query Slots Void Aff
  eval = case _ of

    -----
    -- Parent

    Select tab a -> do
      H.modify_ _ { focus = tab }
      pure a

    -- We can reset both forms to their starting values by leveraging
    -- the `Reset` query from Formless. We also need to reset our various
    -- external components, as Formless doesn't know about them.
    Reset a -> do
      -- To send a query through to a child component when Formless has multiple
      -- child component types, use Send
      _ <- H.query _groupForm unit
        $ Formless.send _typeahead WhiskeyTypeahead
        $ TA.ReplaceSelections (TA.One Nothing) unit
      _ <- H.query _groupForm unit
        $ Formless.send _typeahead ApplicationsTypeahead
        $ TA.ReplaceSelections (TA.Many []) unit
      _ <- H.query _groupForm unit
        $ Formless.send _typeahead PixelsTypeahead
        $ TA.ReplaceSelections (TA.Many []) unit
      _ <- H.query _groupForm unit
        $ Formless.send _dropdown unit
        $ Dropdown.SetSelection Nothing unit

      -- On the Options form, there is no child path to worry about, so we can stick
      -- with the usual data constructor.
      _ <- H.query _optionsForm unit
        $ Formless.send _dropdown unit (Dropdown.SetSelection Nothing unit)

      -- Finally, we can trigger a simple Formless reset on each form.
      _ <- H.query _groupForm unit $ H.action Formless.Reset
      _ <- H.query _optionsForm unit $ H.action Formless.Reset
      pure a

    -- On submit, we need to make sure both forms are run. We
    -- can use the `SubmitReply` query to have submission return
    -- the result directly, rather than via independent messages.
    Submit a -> do
      mbGroupForm <- H.query _groupForm unit $ H.request Formless.SubmitReply
      mbOptionsForm <- H.query _optionsForm unit $ H.request Formless.SubmitReply

      -- Here, we'll construct our new group from the two form outputs.
      case mbGroupForm, mbOptionsForm of
         Just g, Just v -> do
           H.modify_ _ { group = map (over Group (_ { options = v })) g }
         _, _ -> H.liftEffect (Console.error "Forms did not validate.")

      st <- H.get
      H.liftEffect $ Console.log $ show st.group
      pure a

    -----
    -- Group Form

    HandleGroupForm m a -> case m of
      -- We are manually querying Formless to get form submissions
      -- so we can safely ignore this.
      Formless.Submitted _ -> pure a
      Formless.Emit q -> eval q *> pure a
      Formless.Changed fstate -> do
        H.modify_ \st -> st
          { groupFormErrors = fstate.errors
          , groupFormDirty = fstate.dirty
          }
        pure a

    HandleGroupTypeahead slot m a -> case m of
      TA.Emit q -> eval q *> pure a
      TA.SelectionsChanged s v -> do
        let v' = TA.unpackSelections v
        case slot of
          ApplicationsTypeahead -> do
            _ <- H.query _groupForm unit $ Formless.handleBlurAndChange _applications v'
            pure a
          PixelsTypeahead -> do
            _ <- H.query _groupForm unit $ Formless.handleBlurAndChange _pixels v'
            pure a
          WhiskeyTypeahead -> case s of
            TA.ItemSelected x -> do
              _ <- H.query _groupForm unit $ Formless.handleBlurAndChange _whiskey (Just x)
              pure a
            _ -> do
              _ <- H.query _groupForm unit $ Formless.handleBlurAndChange _whiskey Nothing
              pure a
      TA.VisibilityChanged _ -> pure a
      TA.Searched _ -> pure a

    HandleAdminDropdown m a -> case m of
      Dropdown.Emit q -> eval q *> pure a
      Dropdown.VisibilityChanged _ -> pure a
      Dropdown.Selected x -> do
        _ <- H.query _groupForm unit $ Formless.handleBlurAndChange _admin (Just x)
        -- Changing this field should also clear the secret keys. Ensure you use `reset`
        -- instead of `change` as you want to clear errors, too.
        _ <- H.query _groupForm unit $ Formless.handleReset _secretKey1
        _ <- H.query _groupForm unit $ Formless.handleReset _secretKey2
        pure a


    -----
    -- Options Form

    HandleOptionsForm m a -> case m of
      Formless.Emit q -> eval q *> pure a
      Formless.Submitted _ -> pure a
      Formless.Changed fstate -> do
        H.modify_ \st -> st
          { optionsFormErrors = fstate.errors
          , optionsFormDirty = fstate.dirty
          }
        pure a

    HandleMetricDropdown m a -> case m of
      Dropdown.Emit q -> eval q *> pure a
      Dropdown.VisibilityChanged _ -> pure a
      Dropdown.Selected x -> do
        _ <- H.query _optionsForm unit $ Formless.handleBlurAndChange _metric (Just x)
        pure a
