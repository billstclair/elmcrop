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
import Browser.Events as Events
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
    ]
        |> Sub.batch


type alias Model =
    { now : Int
    , url : Url
    , key : Key

    -- Persistent below here
    }


type Msg
    = Nop
    | OnUrlRequest UrlRequest
    | OnUrlChange Url
    | ReloadFromServer
    | RecordTime Posix
    | ReceiveLocalStorage Value
    | InitializeModel


init : Value -> Url -> Key -> ( Model, Cmd Msg )
init flags url key =
    { now = 0
    , url = url
    , key = key
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
            [ style "width" "100%"
            , id "buttonBar"
            ]
            (buttonBar model)
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
    }


viewLeftColumn : Model -> Html Msg
viewLeftColumn model =
    div [ style "height" "256px" ]
        [ text "Drop picture here"
        , div
            [ style "width" "100%"
            , style "height" "100%"
            , style "background-color" "red"
            ]
            []
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
    [ buttonBarButton "Photo-Import-24x24.png" True "Open" Nop
    , largeSpacer
    , buttonBarButton "Photo-Save-24x24.png" True "Save" Nop
    , largeSpacer
    , buttonBarButton "Copy-24x24.png" True "Copy" Nop
    , largeSpacer
    , buttonBarButton "Close-24x24.png" True "Close" Nop
    , largeSpacer
    , buttonBarButton "Rectangular-marquee-tool_34582.png" True "Capture Selection" Nop
    , spacer
    , buttonBarButton "window-24x24.png" True "Capture Window" Nop
    , spacer
    , buttonBarButton "windows-24x24.png" True "Capture Screen" Nop
    , spacer
    , buttonBarButton "timer-24x24.png" True "Timed Capture" Nop
    , largeSpacer
    , buttonBarButton "Information-24x24.png" True "Show Info" Nop
    , span
        [ style "float" "right"
        ]
        [ buttonBarButton "quick-look-24x24.png" True "Quick Look" Nop
        , spacer
        , buttonBarButton "share-24x24.png" True "Share" Nop
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

        InitializeModel ->
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
            let
                printableCommand =
                    Debugging.log "receiveLocalStorage" <|
                        LocalStorage.toPrintableCommand command
            in
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
    let
        json =
            Debugging.log "receiveModel" <| JE.encode 0 value
    in
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
    let
        json =
            Debugging.log ("receiveValue \"" ++ key ++ "\"") <| JE.encode 0 value
    in
    model |> withNoCmd



-- Persistence


type alias Pair =
    { width : Float
    , height : Float
    }


{-| Must be `comparable` for `udpate` to write to `LocalStorage` only when necessary.
-}
type alias SavedModel =
    {}


modelToSavedModel : Model -> SavedModel
modelToSavedModel model =
    {}


savedModelToModel : SavedModel -> Model -> Model
savedModelToModel savedModel model =
    model



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


encodeSavedModel : SavedModel -> Value
encodeSavedModel savedModel =
    JE.object
        []


savedModelDecoder : Decoder SavedModel
savedModelDecoder =
    JD.succeed SavedModel


decodeSavedModel : Value -> Result JD.Error SavedModel
decodeSavedModel value =
    JD.decodeValue savedModelDecoder value
