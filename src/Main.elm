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
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, fieldset, iframe, img, input, legend, p, span, table, td, text, textarea, th, tr, ul)
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
Arg is either a string or { displaySurface: "foo", which: "bar" }
See site/js/captureScreen.js
-}
port captureScreenIn : Value -> Cmd msg


{-| Receive a screen capture as a URL.
-}
port captureScreenOut : (Value -> msg) -> Sub msg


{-| Compute <img> size.
-}
port imgSizeIn : String -> Cmd msg


{-| Receive:
{ id: <id>,
width: <number>, natural-width: <number>,
height: <number>, natural-height: <number>
}
-}
port imgSizeOut : (Value -> msg) -> Sub msg


port playFile : String -> Cmd msg


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


timeSampleRate : Float
timeSampleRate =
    100


minimumDelay : Int
minimumDelay =
    2 * round timeSampleRate


subscriptions : Model -> Sub Msg
subscriptions model =
    [ Time.every timeSampleRate RecordTime
    , LocalStorage.localStorageOut ReceiveLocalStorage
    , captureScreenOut ReceiveCaptureScreen
    , imgSizeOut ReceiveImgSize

    -- TODO: Not quite right. Doesn't become invisible when another app is selected.
    -- Try the `focusin` and `focusout` events
    , Events.onVisibilityChange ChangeVisibility
    , Events.onResize OnResize
    ]
        |> Sub.batch


type alias DelayedCmd =
    { time : Int
    , cmd : Cmd Msg
    }


addDelay : Model -> Int -> Cmd Msg -> Model
addDelay model delay cmd =
    { model
        | delays =
            { time = model.now + delay
            , cmd = cmd
            }
                :: model.delays
    }


delayedCmds : Int -> List DelayedCmd -> ( List (Cmd Msg), List DelayedCmd )
delayedCmds time cmds =
    case cmds of
        [] ->
            ( [], [] )

        delayedCmd :: tail ->
            let
                ( cmdsTail, delayedCmdsTail ) =
                    delayedCmds time tail
            in
            if time <= delayedCmd.time then
                ( delayedCmd.cmd :: cmdsTail, delayedCmdsTail )

            else
                ( cmdsTail, delayedCmd :: delayedCmdsTail )


type alias Model =
    { now : Int
    , url : Url
    , key : Key
    , delays : List DelayedCmd
    , visibility : Visibility
    , captureOnHide : Maybe String
    , windowSize : Maybe ( Int, Int )
    , divViewports : Dict String Viewport
    , imgSizes : Dict String ImgSize

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
    | ReceiveImgSize Value
    | InitializeModel
    | ChangeVisibility Visibility
    | GetViewport Viewport
    | OnResize Int Int
    | GetViewportOf String (Result Dom.Error Viewport)
    | Play String
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
    , delays = []
    , visibility = Visible
    , captureOnHide = Nothing
    , windowSize = Nothing
    , divViewports = Dict.empty
    , imgSizes = Dict.empty

    -- Persistent below here
    , capturedUrl = defaultCapturedUrl
    }
        |> withCmds
            [ Task.perform RecordTime Time.now
            , LocalStorage.setPrefix "elmcrop"
            , Task.perform GetViewport Dom.getViewport
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


playUpDown : Bool
playUpDown =
    False


upMp3 : String
upMp3 =
    "images/up.mp3"


downMp3 : String
downMp3 =
    "images/down.mp3"


view : Model -> Document Msg
view model =
    { title = "ElmCrop"
    , body = viewBody model
    }


viewBody : Model -> List (Html Msg)
viewBody model =
    let
        ( windowWidth, windowHeight ) =
            case model.windowSize of
                Just size ->
                    size

                Nothing ->
                    -- Temporary, should come from restored model
                    ( 400, 400 )

        ( wws, whs ) =
            ( String.fromInt windowWidth ++ "px"
            , String.fromInt windowHeight ++ "px"
            )
    in
    [ div
        [ style "background-color" "#e8e8e8"
        , style "width" wws
        , style "height" whs
        ]
        [ div [ id "top" ]
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
            , br
            ]
        , table
            [ style "width" "100%"
            , style "height" "500px"
            , style "margin-right" "10px"
            ]
            -- TODO
            [ tr [ style "width" "100%" ]
                [ td
                    [ style "width" "49%"
                    , style "height" "490px"
                    ]
                    [ viewLeftColumn model ]
                , td
                    [ style "width" "2%"
                    , style "height" "100%"
                    ]
                    [ text "" ]
                , td
                    [ style "width" "49%"
                    , style "height" "100%"
                    ]
                    [ viewRightColumn model ]
                ]
            ]
        , div [ id "bottom" ]
            [ div [ id "hidemsg" ]
                [ br
                , case model.captureOnHide of
                    Nothing ->
                        text ""

                    Just _ ->
                        p [ style "color" "red" ]
                            [ text <|
                                "Hide the screen to capture ("
                                    ++ chars.command
                                    ++ "H)"
                            ]
                , if playUpDown then
                    p []
                        [ button [ onClick <| Play upMp3 ]
                            [ text "Up" ]
                        , text " "
                        , button [ onClick <| Play downMp3 ]
                            [ text "Down" ]
                        ]

                  else
                    text ""
                ]
            , div [ id "footer" ]
                [ p []
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
    ]


viewLeftColumn : Model -> Html Msg
viewLeftColumn model =
    -- TODO compute height to make content fill window
    div []
        [ div [ id "dropHere" ]
            [ text "Drop picture here" ]
        , div
            [ style "height" "490px"
            , style "background-color" "white"
            , style "border" "1px, solid"
            ]
            [ case model.capturedUrl of
                Nothing ->
                    text ""

                Just capturedUrl ->
                    -- TODO Drag image that is too big to fit
                    img
                        [ src capturedUrl
                        , id "leftImg"
                        , style "object-fit" "cover"
                        , style "width" "100%"
                        , style "height" "100%"
                        ]
                        []
            ]
        ]


viewRightColumn : Model -> Html Msg
viewRightColumn model =
    div []
        [ text "Drag this off"
        , div
            [ style "height" "490px"
            , style "background-color" "blue"
            , style "border" "1px, solid"
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
    , command = codestr 0x2318
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

                ( cmds, delays ) =
                    delayedCmds now model.delays
            in
            { model
                | now = now
                , delays = delays
            }
                |> (if model.now == 0 then
                        addImgSize "leftImg"

                    else
                        identity
                   )
                |> withCmds cmds

        ReceiveLocalStorage value ->
            receiveLocalStorage model value

        ReceiveCaptureScreen value ->
            receiveCaptureScreen model value

        ReceiveImgSize value ->
            receiveImgSize model value

        InitializeModel ->
            model |> withNoCmd

        ChangeVisibility visibility ->
            let
                ( mdl, cmd ) =
                    case model.captureOnHide of
                        Nothing ->
                            ( model, Cmd.none )

                        Just captureOnHide ->
                            if visibility == Hidden then
                                ( { model | captureOnHide = Nothing }
                                , captureScreenIn <| captureScreenArgs "" "capture"
                                )

                            else
                                ( model, Cmd.none )
            in
            { mdl | visibility = Debugging.log "visibility" visibility }
                |> withCmds
                    [ cmd
                    , if playUpDown then
                        playFile <|
                            if visibility == Visible then
                                upMp3

                            else
                                downMp3

                      else
                        Cmd.none
                    ]

        GetViewport viewport ->
            let
                { width, height } =
                    viewport.scene
            in
            gotWindowSize model (round width) (round height)

        OnResize w h ->
            gotWindowSize model w h

        GetViewportOf id result ->
            let
                r =
                    Debugging.log ("GetViewportOf " ++ id) result
            in
            case result of
                Err err ->
                    model |> withNoCmd

                Ok viewport ->
                    { model | divViewports = Dict.insert id viewport model.divViewports }
                        |> withNoCmd

        Play filename ->
            model |> withCmd (playFile filename)

        CloseImage ->
            { model | capturedUrl = defaultCapturedUrl }
                |> addImgSize "leftImg"
                |> withNoCmd

        CaptureScreen displaySurface ->
            let
                ( mdl, cmd ) =
                    if displaySurface /= "monitor" || True then
                        ( model, captureScreenIn <| JE.string displaySurface )

                    else
                        -- This doesn't work, so it never runs
                        -- (due to `|| True` above)
                        ( { model | captureOnHide = Just displaySurface }
                        , captureScreenIn <|
                            captureScreenArgs displaySurface "get"
                        )
            in
            mdl |> withCmd cmd

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


addImgSize : String -> Model -> Model
addImgSize id model =
    addDelay model minimumDelay (imgSizeIn id)


gotWindowSize : Model -> Int -> Int -> ( Model, Cmd Msg )
gotWindowSize model w h =
    let
        wwhh =
            Debugging.log "gotWindowSize" ( w, h )

        cmd =
            Cmd.batch
                [ getViewportOfCmd "top"
                , getViewportOfCmd "bottom"
                , getViewportOfCmd "dropHere"
                ]
    in
    { model
        | windowSize = Just wwhh
        , divViewports = Dict.empty
    }
        |> withCmd cmd


getViewportOfCmd : String -> Cmd Msg
getViewportOfCmd name =
    Task.attempt (GetViewportOf name) <| Dom.getViewportOf name


captureScreenArgs : String -> String -> Value
captureScreenArgs displaySurface which =
    JE.object
        [ ( "displaySurface", JE.string displaySurface )
        , ( "which", JE.string which )
        ]


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
            if string == "" then
                if model.captureOnHide == Nothing then
                    model |> withNoCmd

                else
                    -- TODO: make this enable the second call to
                    -- the captureScreenIn port.
                    -- As a practical matter, the race condition
                    -- won't ever happen.
                    model |> withNoCmd

            else
                { model | capturedUrl = Just string }
                    |> addImgSize "leftImg"
                    |> withNoCmd


type alias ImgSize =
    { id : String
    , width : Int
    , naturalWidth : Int
    , height : Int
    , naturalHeight : Int
    }


receiveImgSize : Model -> Value -> ( Model, Cmd Msg )
receiveImgSize model value =
    let
        json =
            Debugging.log "receiveImgSize" <| JE.encode 0 value
    in
    case decodeImgSize value of
        Err _ ->
            model |> withNoCmd

        Ok imgSize ->
            let
                is =
                    Debugging.log "  decodeImgSize" imgSize
            in
            { model
                | imgSizes =
                    Dict.insert imgSize.id imgSize model.imgSizes
            }
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


imgSizeDecoder : Decoder ImgSize
imgSizeDecoder =
    JD.succeed ImgSize
        |> required "id" JD.string
        |> required "width" JD.int
        |> required "naturalWidth" JD.int
        |> required "height" JD.int
        |> required "naturalHeight" JD.int


decodeImgSize : Value -> Result JD.Error ImgSize
decodeImgSize value =
    JD.decodeValue imgSizeDecoder value
