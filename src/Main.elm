---------------------------------------------------------------------
--
-- Main.elm
-- ElmCrop - Clone of EasyCrop, in Elm, on the web.
-- Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE
--
-- TODO:
--
-- Sometimes the capturedUrl fails to convert (from LocalStorage).
--   Don't know why yet.
--
-------------------------------------------------------------------------------


port module Main exposing (main)

--

import Browser exposing (Document, UrlRequest(..))
import Browser.Dom as Dom exposing (Viewport)
import Browser.Events as Events exposing (Visibility(..))
import Browser.Navigation as Navigation exposing (Key)
import Cmd.Extra exposing (addCmd, withCmd, withCmds, withNoCmd)
import Debugging
import Dict exposing (Dict)
import File exposing (File)
import Html exposing (Html, a, button, div, fieldset, iframe, img, input, legend, p, span, table, td, text, textarea, th, tr, ul)
import Html.Attributes as Attributes exposing (align, alt, checked, disabled, height, href, id, name, size, src, style, title, type_, value, width)
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


addDelay : Int -> Cmd Msg -> Model -> Model
addDelay delay cmd model =
    { model
        | delays =
            { time = model.now + delay
            , cmd = cmd
            }
                :: model.delays
    }


delayedCmds : Int -> List DelayedCmd -> ( List (Cmd Msg), List DelayedCmd )
delayedCmds time cmds =
    let
        loop nowCmds cmdsTail =
            case cmdsTail of
                [] ->
                    ( List.reverse nowCmds, [] )

                delayedCmd :: tail ->
                    let
                        ( cmdsTail2, delayedCmdsTail ) =
                            loop nowCmds tail
                    in
                    if time >= delayedCmd.time then
                        ( delayedCmd.cmd :: cmdsTail2, delayedCmdsTail )

                    else
                        ( cmdsTail2, delayedCmd :: delayedCmdsTail )
    in
    loop [] cmds


type alias WindowSize =
    ( Int, Int )


type alias Model =
    { now : Int
    , url : Url
    , key : Key
    , delays : List DelayedCmd
    , visibility : Visibility
    , captureOnHide : Maybe String

    -- Persisted separately from Model
    , capturedUrl : Maybe String

    -- Persistent below here
    , windowSize : Maybe WindowSize
    , divViewports : Dict String Viewport
    , imgSizes : Dict String ImgSize
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
    | GotViewport Viewport
    | OnResize Int Int
    | GotViewportOf String (Result Dom.Error Viewport)
    | Play String
    | CloseImage
    | CaptureScreen String
    | TimedCaptureScreen
    | SetCapturedUrl String
    | Drop (List File)


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
        |> addDelay minimumDelay
            (Task.perform GotViewport Dom.getViewport)
        |> withCmds
            [ Task.perform RecordTime Time.now
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


type alias ViewSizes =
    { width : Int
    , height : Int
    , topHeight : Int
    , dropHereHeight : Int --"Drop picture here", "Drag this off"
    , borderWidth : Int
    , tableHeight : Int
    , tableWidth : Int
    , tableRightMargin : Int
    , leftColumnWidth : Int
    , centerColumnWidth : Int
    , rightColumnWidth : Int
    , bottomHeight : Int
    }


zeroViewport : Viewport
zeroViewport =
    { scene =
        { width = 0
        , height = 0
        }
    , viewport =
        { x = 0
        , y = 0
        , width = 0
        , height = 0
        }
    }


computeViewSizes : Model -> ViewSizes
computeViewSizes model =
    let
        divViewports =
            model.divViewports

        topViewport =
            case Dict.get "top" divViewports of
                Just top ->
                    top

                Nothing ->
                    zeroViewport

        bottomViewport =
            case Dict.get "bottom" divViewports of
                Just bottom ->
                    bottom

                Nothing ->
                    zeroViewport

        dropHereViewport =
            case Dict.get "dropHere" divViewports of
                Just dropHere ->
                    dropHere

                Nothing ->
                    zeroViewport

        ( width, height ) =
            case model.windowSize of
                Just size ->
                    size

                Nothing ->
                    -- Don't know if this will ever matter
                    ( 400, 400 )

        topHeight =
            round topViewport.viewport.height

        bottomHeight =
            round bottomViewport.viewport.height

        dropHereHeight =
            round dropHereViewport.viewport.height

        centerColumnWidth =
            10

        tableRightMargin =
            10

        borderWidth =
            1

        tableWidth =
            -- the 10 is from I know not where
            width - tableRightMargin - 10

        -- TODO: drag center column to resize table
        leftColumnWidth =
            (tableWidth
                - centerColumnWidth
                - tableRightMargin
                - (2 * borderWidth)
            )
                // 2

        rightColumnWidth =
            leftColumnWidth
    in
    { width = width
    , height = height
    , topHeight = topHeight
    , dropHereHeight = dropHereHeight

    -- the 10 is from I know not where
    , tableHeight = height - topHeight - bottomHeight - dropHereHeight - 10
    , tableWidth = tableWidth
    , borderWidth = borderWidth
    , tableRightMargin = tableRightMargin
    , leftColumnWidth = leftColumnWidth
    , centerColumnWidth = centerColumnWidth
    , rightColumnWidth = rightColumnWidth
    , bottomHeight = bottomHeight
    }


px : Int -> String
px x =
    String.fromInt x ++ "px"


view : Model -> Document Msg
view model =
    { title = "ElmCrop"
    , body = viewBody model
    }


viewBody : Model -> List (Html Msg)
viewBody model =
    let
        viewSizes =
            computeViewSizes model
    in
    [ div
        (List.concat
            [ [ style "background-color" "#e8e8e8"
              , style "width" <| px viewSizes.width
              , style "height" <| px viewSizes.height
              , Html.Events.custom "dragenter" dragEnterDecoder
              , Html.Events.custom "dragover" dragEnterDecoder
              , Html.Events.custom "dragleave" dragEnterDecoder
              , Html.Events.custom "drop" dropDecoder
              ]

            -- TODO: Fix type mismatch
            --, dzehAttributes
            ]
        )
        [ div
            [ id "top"
            , style "width" <| px viewSizes.tableWidth
            ]
            [ div
                [ style "background-color" "lightgray"
                , style "margin" "0"
                , style "width" <| px viewSizes.tableWidth
                ]
                [ div
                    [ style "width" <| px (viewSizes.tableWidth - 20)
                    , style "padding" "10px"
                    , id "buttonBar"
                    ]
                    (buttonBar model)
                ]
            , br
            ]
        , table
            [ style "table-layout" "fixed"
            , style "width" <| px viewSizes.tableWidth
            , style "height" <| px viewSizes.tableHeight
            , style "margin-right" <| px viewSizes.tableRightMargin
            ]
            [ tr
                [ style "width" <| px viewSizes.tableWidth
                , style "height" <| px viewSizes.tableHeight
                ]
                [ td
                    [ style "width" <| px viewSizes.leftColumnWidth
                    , style "height" <| px viewSizes.tableHeight
                    ]
                    [ viewLeftColumn model viewSizes ]
                , td
                    [ style "width" <| px viewSizes.centerColumnWidth
                    , style "height" <| px viewSizes.tableHeight
                    ]
                    [ text "" ]
                , td
                    [ style "width" <| px viewSizes.rightColumnWidth
                    , style "height" <| px viewSizes.tableHeight
                    ]
                    [ viewRightColumn model viewSizes ]
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


viewLeftColumn : Model -> ViewSizes -> Html Msg
viewLeftColumn model viewSizes =
    div []
        [ div [ id "dropHere" ]
            [ text "Drop picture here" ]
        , div
            [ style "width" <|
                px (viewSizes.leftColumnWidth - (2 * viewSizes.borderWidth))
            , style "height" <| px (viewSizes.tableHeight - viewSizes.dropHereHeight)
            , style "background-color" "white"
            , style "border" <| px viewSizes.borderWidth ++ ", solid"
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


viewRightColumn : Model -> ViewSizes -> Html Msg
viewRightColumn model viewSizes =
    div []
        [ text "Drag this off"
        , div
            [ style "width" <|
                px (viewSizes.leftColumnWidth - (2 * viewSizes.borderWidth))
            , style "height" <| px (viewSizes.tableHeight - viewSizes.dropHereHeight)
            , style "background-color" "blue"
            , style "border" <| px viewSizes.borderWidth ++ ", solid"
            ]
            []
        ]


buttonBarButton : String -> Bool -> String -> Msg -> Html Msg
buttonBarButton imgName enabled title msg =
    Html.span
        [ Attributes.title title
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

        GotViewport viewport ->
            let
                vp =
                    Debugging.log "GotViewport" viewport

                { width, height } =
                    viewport.viewport
            in
            gotWindowSize model (round width) (round height)
                |> withCmd (LocalStorage.setPrefix "elmcrop")

        OnResize w h ->
            gotWindowSize model w h
                |> withNoCmd

        GotViewportOf id result ->
            let
                r =
                    Debugging.log ("GotViewportOf \"" ++ id ++ "\"") result
            in
            case result of
                Err err ->
                    model |> withNoCmd

                Ok viewport ->
                    { model
                        | divViewports =
                            Dict.insert id viewport model.divViewports
                    }
                        |> withNoCmd

        Play filename ->
            model |> withCmd (playFile filename)

        CloseImage ->
            let
                cmd =
                    case defaultCapturedUrl of
                        Nothing ->
                            Cmd.none

                        Just url ->
                            saveCapturedUrl url
            in
            { model | capturedUrl = defaultCapturedUrl }
                |> addImgSize "leftImg"
                |> withCmd cmd

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

        SetCapturedUrl url ->
            let
                urlHead =
                    logLongString "SetCapturedUrl" url
            in
            { model | capturedUrl = Just url }
                |> addImgSize "leftImg"
                |> withCmd (saveCapturedUrl url)

        Drop files ->
            let
                ignore =
                    Debugging.log "Drop" files
            in
            case List.head files of
                Nothing ->
                    model |> withNoCmd

                Just file ->
                    model
                        |> withCmd
                            (Task.perform SetCapturedUrl <| File.toUrl file)

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


dragEnterDecoder : Decoder { message : Msg, preventDefault : Bool, stopPropagation : Bool }
dragEnterDecoder =
    JD.succeed
        { message = Nop
        , preventDefault = True
        , stopPropagation = False
        }


dropDecoder : Decoder { message : Msg, preventDefault : Bool, stopPropagation : Bool }
dropDecoder =
    JD.value
        |> JD.andThen
            (\value ->
                let
                    v2 =
                        Debugging.log "dropDecoder value" <| JE.encode 0 value
                in
                JD.map
                    (\files ->
                        { message = Drop files
                        , preventDefault = True
                        , stopPropagation = True
                        }
                    )
                    filesDecoder
            )


filesDecoder : Decoder (List File)
filesDecoder =
    JD.field "dataTransfer" (JD.field "files" (JD.list File.decoder))


addImgSize : String -> Model -> Model
addImgSize id model =
    addDelay minimumDelay (imgSizeIn id) model


gotWindowSize : Model -> Int -> Int -> Model
gotWindowSize model w h =
    let
        wwhh =
            Debugging.log "gotWindowSize" ( w, h )
    in
    { model
        | windowSize = Just wwhh
    }
        |> addDelay minimumDelay
            (Cmd.batch
                [ gotViewportOfCmd "top"
                , gotViewportOfCmd "bottom"
                , gotViewportOfCmd "dropHere"
                ]
            )


gotViewportOfCmd : String -> Cmd Msg
gotViewportOfCmd name =
    Task.attempt (GotViewportOf name) <| Dom.getViewportOf name


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
                    model |> withCmd (LocalStorage.get "capturedUrl")

                Get ->
                    if command.key == "capturedUrl" then
                        receiveCapturedUrl command.value model

                    else if command.key == "model" then
                        receiveModel command.value model

                    else
                        receiveValue command.key command.value model

                _ ->
                    model |> withNoCmd


logLongString : String -> String -> String
logLongString label value =
    Debugging.log label <|
        String.left 50 value
            ++ "..."


receiveCapturedUrl : Value -> Model -> ( Model, Cmd Msg )
receiveCapturedUrl value model =
    let
        withGetModelCmd =
            withCmd <| LocalStorage.get "model"

        json =
            logLongString "receiveCapturedUrl" <| JE.encode 0 value
    in
    if value == JE.null then
        model |> withGetModelCmd

    else
        case JD.decodeValue JD.string value of
            Err err ->
                let
                    err2 =
                        Debugging.log "ReceiveCapturedUrl error" err
                in
                model |> withGetModelCmd

            Ok url ->
                { model | capturedUrl = Just url }
                    |> withGetModelCmd


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
                model |> withCmd (Task.perform SetCapturedUrl <| Task.succeed string)


saveCapturedUrl : String -> Cmd msg
saveCapturedUrl capturedUrl =
    LocalStorage.put "capturedUrl" <| JE.string capturedUrl


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
    { windowSize : Maybe WindowSize
    , divViewports : Dict String Viewport
    , imgSizes : Dict String ImgSize
    }


modelToSavedModel : Model -> SavedModel
modelToSavedModel model =
    { windowSize = model.windowSize
    , divViewports = model.divViewports
    , imgSizes = model.imgSizes
    }


savedModelToModel : SavedModel -> Model -> Model
savedModelToModel savedModel model =
    { model
        | windowSize = savedModel.windowSize
        , divViewports = savedModel.divViewports
        , imgSizes = savedModel.imgSizes
    }



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
        [ ( "windowSize", encodeMaybe windowSizeEncoder savedModel.windowSize )
        , ( "divViewports", JE.dict identity encodeViewport savedModel.divViewports )
        , ( "imgSizes", JE.dict identity encodeImgSize savedModel.imgSizes )
        ]


savedModelDecoder : Decoder SavedModel
savedModelDecoder =
    JD.succeed SavedModel
        |> optional "windowSize" (JD.nullable windowSizeDecoder) Nothing
        |> optional "divViewports" (JD.dict viewportDecoder) Dict.empty
        |> optional "imgSizes" (JD.dict imgSizeDecoder) Dict.empty


decodeSavedModel : Value -> Result JD.Error SavedModel
decodeSavedModel value =
    JD.decodeValue savedModelDecoder value


windowSizeEncoder : WindowSize -> Value
windowSizeEncoder ( width, height ) =
    JE.object
        [ ( "w", JE.int width )
        , ( "h", JE.int height )
        ]


type alias WindowSizeRecord =
    { w : Int
    , h : Int
    }


windowSizeDecoder : Decoder WindowSize
windowSizeDecoder =
    (JD.succeed WindowSizeRecord
        |> required "w" JD.int
        |> required "h" JD.int
    )
        |> JD.andThen
            (\rec ->
                JD.succeed ( rec.w, rec.h )
            )


type alias ViewportScene =
    { width : Float
    , height : Float
    }


encodeViewportScene : ViewportScene -> Value
encodeViewportScene scene =
    JE.object
        [ ( "width", JE.float scene.width )
        , ( "height", JE.float scene.height )
        ]


viewportSceneDecoder : Decoder ViewportScene
viewportSceneDecoder =
    JD.succeed ViewportScene
        |> required "width" JD.float
        |> required "height" JD.float


type alias ViewportViewport =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }


encodeViewportViewport : ViewportViewport -> Value
encodeViewportViewport vpvp =
    JE.object
        [ ( "x", JE.float vpvp.x )
        , ( "y", JE.float vpvp.y )
        , ( "width", JE.float vpvp.width )
        , ( "height", JE.float vpvp.height )
        ]


viewportViewportDecoder : Decoder ViewportViewport
viewportViewportDecoder =
    JD.succeed ViewportViewport
        |> required "x" JD.float
        |> required "y" JD.float
        |> required "width" JD.float
        |> required "height" JD.float


encodeViewport : Viewport -> Value
encodeViewport viewport =
    JE.object
        [ ( "scene", encodeViewportScene viewport.scene )
        , ( "viewport", encodeViewportViewport viewport.viewport )
        ]


viewportDecoder : Decoder Viewport
viewportDecoder =
    JD.succeed Viewport
        |> required "scene" viewportSceneDecoder
        |> required "viewport" viewportViewportDecoder


encodeImgSize : ImgSize -> Value
encodeImgSize imgSize =
    JE.object
        [ ( "id", JE.string imgSize.id )
        , ( "width", JE.int imgSize.width )
        , ( "naturalWidth", JE.int imgSize.naturalWidth )
        , ( "height", JE.int imgSize.height )
        , ( "naturalHeight", JE.int imgSize.naturalHeight )
        ]


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
