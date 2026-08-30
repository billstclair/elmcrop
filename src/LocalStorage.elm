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
    , encodeCommand
    , get
    , localStorageIn
    , localStorageOut
    , put
    )

import Json.Decode as JD exposing (Decoder)
import Json.Decode.Pipeline as DP exposing (custom, hardcoded, optional, required)
import Json.Encode as JE exposing (Value)


type GetOrPut
    = Get
    | Put


type alias Command =
    { getOrPut : GetOrPut
    , label : String
    , val : Value
    }


get : String -> String -> Cmd msg
get label key =
    { getOrPut = Get
    , label = label
    , val = JE.string key
    }
        |> encodeCommand
        |> localStorageIn


put : String -> Value -> Cmd msg
put label value =
    { getOrPut = Put
    , label = label
    , val = value
    }
        |> encodeCommand
        |> localStorageIn


encodeCommand : Command -> Value
encodeCommand command =
    JE.object
        [ ( "getOrPut"
          , JE.string
                (case command.getOrPut of
                    Get ->
                        "get"

                    Put ->
                        "put"
                )
          )
        , ( "label", JE.string command.label )
        , ( "val", command.val )
        ]


commandDecoder : Decoder Command
commandDecoder =
    JD.succeed Command
        |> required "getOrPut" getOrPutDecoder
        |> required "label" JD.string
        |> required "val" JD.value


getOrPutDecoder : Decoder GetOrPut
getOrPutDecoder =
    JD.string
        |> JD.andThen
            (\s ->
                if s == "Get" then
                    JD.succeed Get

                else if s == "Put" then
                    JD.succeed Put

                else
                    JD.fail "Not Get or Put"
            )


{-| Send a `Command` over from Elm.
-}
port localStorageIn : Value -> Cmd msg


{-| Send a `Command` back, containing a value.
-}
port localStorageOut : (Value -> msg) -> Sub msg
