---------------------------------------------------------------
--
-- LocalStorage.elm
-- Elm interface to JS LocalStorage.
-- Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE
--
----------------------------------------------------------------------


port module LocalStorage exposing
    ( Command
    , GetOrPut(..)
    , commandDecoder
    , decodeCommand
    , encodeCommand
    , get
    , getLabeled
    , localStorageIn
    , localStorageOut
    , put
    , putLabeled
    , setPrefix
    )

import Debugging
import Json.Decode as JD exposing (Decoder)
import Json.Decode.Pipeline as DP exposing (custom, hardcoded, optional, required)
import Json.Encode as JE exposing (Value)


type GetOrPut
    = Get
    | Put
    | SetPrefix


type alias Command =
    { getOrPut : GetOrPut
    , key : String
    , label : String
    , value : Value
    }


get : String -> Cmd msg
get key =
    getLabeled key ""


getLabeled : String -> String -> Cmd msg
getLabeled key label =
    { getOrPut = Get
    , key = key
    , label = label
    , value = JE.null
    }
        |> encodeCommand
        |> localStorageIn


setPrefix : String -> Cmd msg
setPrefix prefix =
    { getOrPut = SetPrefix
    , key = prefix
    , label = ""
    , value = JE.null
    }
        |> encodeCommand
        |> localStorageIn


put : String -> Value -> Cmd msg
put key value =
    putLabeled key "" value


putLabeled : String -> String -> Value -> Cmd msg
putLabeled key label value =
    { getOrPut = Put
    , key = key
    , label = label
    , value = value
    }
        |> encodeCommand
        |> localStorageIn


encodeCommand : Command -> Value
encodeCommand command =
    let
        cmd =
            Debugging.log "LocalStorage send" command
    in
    JE.object
        [ ( "getOrPut"
          , JE.string
                (case command.getOrPut of
                    Get ->
                        "get"

                    Put ->
                        "put"

                    SetPrefix ->
                        "setprefix"
                )
          )
        , ( "key", JE.string command.key )
        , ( "label", JE.string command.label )
        , ( "value", command.value )
        ]


commandDecoder : Decoder Command
commandDecoder =
    JD.succeed Command
        |> required "getOrPut" getOrPutDecoder
        |> required "key" JD.string
        |> required "label" JD.string
        |> optional "value" JD.value JE.null


getOrPutDecoder : Decoder GetOrPut
getOrPutDecoder =
    JD.string
        |> JD.andThen
            (\s ->
                if s == "get" then
                    JD.succeed Get

                else if s == "put" then
                    JD.succeed Put

                else if s == "setprefix" then
                    JD.succeed SetPrefix

                else
                    JD.fail "Not get or put"
            )


decodeCommand : Value -> Result JD.Error Command
decodeCommand value =
    JD.decodeValue commandDecoder value


{-| Send a `Command` over from Elm.
-}
port localStorageIn : Value -> Cmd msg


{-| Send a `Command` back, containing a value.
-}
port localStorageOut : (Value -> msg) -> Sub msg
