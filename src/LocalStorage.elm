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


port module LocalStorage exposing (localStorageIn, localStorageOut)

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


encodeCmd : Command -> Value
encodeCmd command =
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


port localStorageIn : Value -> Cmd msg


port localStorageOut : (Value -> msg) -> Sub msg
