---------------------------------------------------------------
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
import Browser.Dom as Dom
import Browser.Navigation as Navigation exposing (Key)
import Cmd.Extra exposing (addCmd, withCmd, withCmds, withNoCmd)
import Html exposing (Html, a, div, fieldset, iframe, img, input, legend, p, span, table, td, text, textarea, th, tr, ul)
import Html.Attributes exposing (align, checked, disabled, height, href, id, name, size, src, style, type_, value, width)
import Html.Events exposing (onClick, onFocus, onInput)
import Json.Encode as JE exposing (Value)
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
    Time.every 1000 RecordTime



-- standard window size: 840x550


type alias Model =
    { now : Posix
    , url : Url
    , key : Key
    }


type Msg
    = Nop
    | OnUrlRequest UrlRequest
    | OnUrlChange Url
    | ReloadFromServer
    | RecordTime Posix


init : Value -> Url -> Key -> ( Model, Cmd Msg )
init flags url key =
    { now = Time.millisToPosix 0
    , url = url
    , key = key
    }
        |> withCmd (Task.perform RecordTime Time.now)


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
            , id "menubar"
            ]
            (menubar model)
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
                , text "Copyright 2026, Bill St. Clair"
                , br
                , a [ href "https://github.com/billstclair/elmcrop" ]
                    [ text "GitHub" ]
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


menubar : Model -> List (Html Msg)
menubar model =
    [ text "menubar" ]


codestr code =
    String.fromList [ Char.fromCode code ]


chars =
    { leftCurlyQuote = codestr 0x201C
    , copyright = codestr 0xA9
    , nbsp = codestr 0xA0
    }


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
    case msg of
        Nop ->
            model |> withNoCmd

        RecordTime posix ->
            let
                now =
                    Time.posixToMillis posix
            in
            { model
                | now = posix
            }
                |> withNoCmd

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
