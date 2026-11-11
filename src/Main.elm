----------------------------------------------------------------------
--
-- Main.elm
-- elmcrop - Clone of EasyCrop, in Elm, on the web.
-- Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE
--
----------------------------------------------------------------------


port module Main exposing (main)

--

import Browser exposing (Document, UrlRequest(..))
import Browser.Dom as Dom exposing (Viewport)
import Browser.Events as Events exposing (Visibility(..))
import Browser.Navigation as Navigation exposing (Key)
import Cmd.Extra exposing (addCmd, withCmd, withCmds, withNoCmd)
import Debugging
import Html exposing (Html, a, div, fieldset, iframe, img, input, legend, p, span, table, td, text, textarea, th, tr, ul)
import Html.Attributes exposing (align, alt, checked, disabled, height, href, id, name, size, src, style, title, type_, value, width)
import Html.Events exposing (onClick, onFocus, onInput)
import Json.Decode as JD exposing (Decoder)
import Json.Decode.Pipeline as DP exposing (custom, hardcoded, optional, required)
import Json.Encode as JE exposing (Value)
import LocalStorage exposing (Command, GetOrPut(..))
import Task exposing (Task)
import Time exposing (Posix)
import Url exposing (Url)


{-| Capture the screen, and send a URL to captureScreenOut.
-}
port captureScreenIn : Value -> Cmd msg


{-| Receive a screen capture as a URL.
-}
port captureScreenOut : (Value -> msg) -> Sub msg


port selectAll : String -> Cmd msg


port openWindow : Value -> Cmd msg


main =
    Browser.application
        { init = init
        , onUrlRequest = OnUrlRequest
        , onUrlChange = OnUrlChange
        , subscriptions = subscriptions
        , update = update
        , view = view
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Time.every 1000 RecordTime
    , LocalStorage.localStorageOut ReceiveLocalStorage
    , captureScreenOut ReceiveCaptureScreen

    -- TODO: Not quite right. Doesn't become invisible when another app is selected.
    -- Try the `focusin` and `focusout` events
    , Events.onVisibilityChange ChangeVisibility
    ]
        |> Sub.batch


type alias Model =
    { now : Int
    , url : Url
    , key : Key
    , visibility : Visibility

    -- Persistent below here
    , capturedUrl : Maybe String
    }


type Msg
    = Nop
    | OnUrlRequest UrlRequest
    | OnUrlChange Url
    | ReloadFromServer
    | RecordTime Posix
    | ReceiveLocalStorage Value
    | ReceiveCaptureScreen Value
    | InitializeModel
    | ChangeVisibility Visibility
    | CloseImage
    | CaptureScreen String
    | TimedCaptureScreen


defaultCapturedUrl : Maybe String
defaultCapturedUrl =
    Just "images/icon-512.png"


init : Value -> Url -> Key -> ( Model, Cmd Msg )
init flags url key =
    { now = 0
    , url = url
    , key = key
    , visibility = Visible
    , capturedUrl = defaultCapturedUrl
    }
        |> withCmds
            [ Task.perform RecordTime Time.now
            , LocalStorage.setPrefix "elmcrop"
            ]


h1 : String -> Html msg
h1 string =
    Html.h1 [] [ text string ]


b : String -> Html msg
b string =
    Html.b []
        [ Html.text string ]


br : Html msg
br =
    Html.br [] []


view : Model -> Document Msg
view model =
    { title = "ElmCrop"
    , body =
        [ div
            [ style "background-color" "#e8e8e8" ]
            [ div
                [ style "background-color" "lightgray"
                , style "margin" "0"
                ]
                [ div
                    [ style "width" "100%"
                    , style "padding" "10px"
                    , id "buttonBar"
                    ]
                    (buttonBar model)
                ]
            , table
                [ style "width" "100%"
                ]
                -- TODO
                [ tr
                    [ style "width" "100%"
                    ]
                    [ td
                        [ style "width" "49%"
                        ]
                        [ viewLeftColumn model ]
                    , td
                        [ style "width" "2%"
                        ]
                        [ text "" ]
                    , td
                        [ style "width" "49%"
                        ]
                        [ viewRightColumn model ]
                    ]
                ]
            , div [ id "footer" ]
                [ br
                , p []
                    [ a
                        [ href "#"
                        , onClick ReloadFromServer
                        ]
                        [ text "Reload from Server" ]
                    ]
                , p []
                    [ text chars.copyright
                    , text "Copyright 2026, "
                    , a [ href "https://billstclair.com/" ]
                        [ text "Bill St. Clair" ]
                    , br
                    , a [ href "https://elm-lang.org" ]
                        [ img
                            [ src "images/elm-logo-125x125.png"
                            , alt "Elm"
                            , height 24
                            ]
                            []
                        ]
                    , text " "
                    , a [ href "https://github.com/billstclair/elmcrop" ]
                        [ img
                            [ src "images/GitHub-Mark-32px.png"
                            , alt "GitHub"
                            , height 24
                            ]
                            []
                        ]
                    ]
                ]
            ]
        ]
    }


viewLeftColumn : Model -> Html Msg
viewLeftColumn model =
    -- TODO compute height to make content fill window
    div [ style "height" "256px" ]
        [ text "Drop picture here"
        , div
            [ style "width" "100%"
            , style "height" "100%"
            , style "background-color" "white"
            ]
            [ case model.capturedUrl of
                Nothing ->
                    text ""

                Just capturedUrl ->
                    -- TODO Drag image that is too big to fit
                    img
                        [ src capturedUrl
                        , style "object-fit" "cover"
                        , style "width" "100%"
                        , style "height" "100%"
                        ]
                        []
            ]
        ]


viewRightColumn : Model -> Html Msg
viewRightColumn model =
    div [ style "height" "256px" ]
        [ text "Drag this off"
        , div
            [ style "width" "100%"
            , style "height" "100%"
            , style "background-color" "blue"
            ]
            []
        ]


buttonBarButton : String -> Bool -> String -> Msg -> Html Msg
buttonBarButton imgName enabled title msg =
    Html.span
        [ Html.Attributes.title title
        , style "width" "100%"
        , onClick msg
        , style "cursor" <|
            if enabled then
                "pointer"

            else
                "auto"
        ]
        [ img
            [ src <|
                "images/icons/"
                    ++ (if enabled then
                            ""

                        else
                            "disabled/"
                       )
                    ++ imgName
            , style "width" "24px"
            , style "height" "24px"
            ]
            []
        ]


spacer : Html msg
spacer =
    span []
        [ nbsp
        , nbsp
        ]


largeSpacer : Html msg
largeSpacer =
    span []
        [ spacer
        , spacer
        , spacer
        ]


buttonBar : Model -> List (Html Msg)
buttonBar model =
    let
        visible =
            model.visibility == Visible
    in
    [ buttonBarButton "Photo-Import-24x24.png" visible "Open" Nop
    , largeSpacer
    , buttonBarButton "Photo-Save-24x24.png" visible "Save" Nop
    , largeSpacer
    , buttonBarButton "Copy-24x24.png" visible "Copy" Nop
    , largeSpacer
    , buttonBarButton "Close-24x24.png" visible "Close" CloseImage
    , largeSpacer

    --, buttonBarButton "Rectangular-marquee-tool_34582.png" visible "Capture Selection" Nop
    --, spacer
    , buttonBarButton "window-24x24.png" visible "Capture Window" <|
        CaptureScreen "window"
    , spacer
    , buttonBarButton "windows-24x24.png" visible "Capture Screen" <|
        CaptureScreen "monitor"
    , spacer
    , buttonBarButton "timer-24x24.png" visible "Timed Capture" TimedCaptureScreen
    , largeSpacer
    , buttonBarButton "Information-24x24.png" visible "Show Info" Nop
    , span
        [ style "float" "right"
        , style "margin-right" "10px"
        ]
        [ buttonBarButton "quick-look-24x24.png" visible "Quick Look" Nop
        , spacer
        , buttonBarButton "share-24x24.png" visible "Share" Nop
        ]
    ]


codestr code =
    String.fromList [ Char.fromCode code ]


chars =
    { leftCurlyQuote = codestr 0x201C
    , copyright = codestr 0xA9
    , nbsp = codestr 0xA0
    }


nbsp : Html msg
nbsp =
    text chars.nbsp


addPointZero : String -> String
addPointZero string =
    if String.contains "." string then
        string

    else
        string ++ ".0"


addZero : String -> String
addZero string =
    if string == "" then
        "0"

    else if String.left 1 string == "0" then
        addZero <| String.dropLeft 1 string

    else
        string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        ( newModel, cmd ) =
            updateInternal msg model

        oldSavedModel =
            modelToSavedModel model

        newSavedModel =
            modelToSavedModel newModel
    in
    newModel
        |> withCmds
            [ cmd
            , if newSavedModel /= oldSavedModel then
                LocalStorage.put "model" <| encodeSavedModel newSavedModel

              else
                Cmd.none
            ]


updateInternal : Msg -> Model -> ( Model, Cmd Msg )
updateInternal msg model =
    case msg of
        Nop ->
            model |> withNoCmd

        RecordTime posix ->
            let
                now =
                    Time.posixToMillis posix
            in
            { model
                | now = now
            }
                |> withNoCmd

        ReceiveLocalStorage value ->
            receiveLocalStorage model value

        ReceiveCaptureScreen value ->
            receiveCaptureScreen model value

        InitializeModel ->
            model |> withNoCmd

        ChangeVisibility visibility ->
            { model | visibility = Debugging.log "visibility" visibility }
                |> withNoCmd

        CloseImage ->
            { model | capturedUrl = defaultCapturedUrl }
                |> withNoCmd

        CaptureScreen displaySurface ->
            model |> withCmd (captureScreenIn <| JE.string displaySurface)

        TimedCaptureScreen ->
            -- TODO
            model |> withNoCmd

        OnUrlChange url ->
            model |> withNoCmd

        OnUrlRequest urlRequest ->
            case urlRequest of
                External url ->
                    model |> withCmd (openWindow <| JE.string url)

                Internal url ->
                    model |> withNoCmd

        ReloadFromServer ->
            model |> withCmd Navigation.reloadAndSkipCache


receiveLocalStorage : Model -> Value -> ( Model, Cmd Msg )
receiveLocalStorage model value =
    case LocalStorage.decodeCommand value of
        Err err ->
            let
                json =
                    Debugging.log "receiveLocalStorage error, value" <|
                        JE.encode 0 value

                errString =
                    Debugging.log "  " <| JD.errorToString err
            in
            model |> withNoCmd

        Ok command ->
            case command.getOrPut of
                SetPrefix ->
                    model |> withCmd (LocalStorage.get "model")

                Get ->
                    if command.key == "model" then
                        receiveModel command.value model

                    else
                        receiveValue command.key command.value model

                _ ->
                    model |> withNoCmd


receiveModel : Value -> Model -> ( Model, Cmd Msg )
receiveModel value model =
    if value == JE.null then
        model |> withNoCmd

    else
        case decodeSavedModel value of
            Err err ->
                let
                    err2 =
                        Debugging.log "Error decoding model" err
                in
                model |> withNoCmd

            Ok savedModel ->
                let
                    newModel =
                        savedModelToModel savedModel model
                in
                newModel
                    |> withNoCmd


receiveValue : String -> Value -> Model -> ( Model, Cmd Msg )
receiveValue key value model =
    model |> withNoCmd


receiveCaptureScreen : Model -> Value -> ( Model, Cmd Msg )
receiveCaptureScreen model value =
    case JD.decodeValue JD.string value of
        Err err ->
            let
                err2 =
                    Debugging.log "receiveCaptureScreen error" err
            in
            model |> withNoCmd

        Ok string ->
            { model | capturedUrl = Just string }
                |> withNoCmd



-- Persistence


type alias Pair =
    { width : Float
    , height : Float
    }


{-| Must be `comparable` for `udpate` to write to `LocalStorage` only when necessary.
-}
type alias SavedModel =
    { capturedUrl : Maybe String
    }


modelToSavedModel : Model -> SavedModel
modelToSavedModel model =
    { capturedUrl = model.capturedUrl }


savedModelToModel : SavedModel -> Model -> Model
savedModelToModel savedModel model =
    { model | capturedUrl = savedModel.capturedUrl }



-- encoders/decoders


encodePair : Pair -> Value
encodePair pair =
    JE.object
        [ ( "width", JE.float pair.width )
        , ( "height", JE.float pair.height )
        ]


pairDecoder : Decoder Pair
pairDecoder =
    JD.succeed Pair
        |> required "width" JD.float
        |> required "height" JD.float


encodeMaybe : (x -> Value) -> Maybe x -> Value
encodeMaybe encoder maybeX =
    case maybeX of
        Nothing ->
            JE.null

        Just x ->
            encoder x


encodeSavedModel : SavedModel -> Value
encodeSavedModel savedModel =
    JE.object
        [ ( "capturedUrl", encodeMaybe JE.string <| savedModel.capturedUrl ) ]


savedModelDecoder : Decoder SavedModel
savedModelDecoder =
    JD.succeed SavedModel
        |> required "capturedUrl" (JD.nullable JD.string)


decodeSavedModel : Value -> Result JD.Error SavedModel
decodeSavedModel value =
    JD.decodeValue savedModelDecoder value
