---------------------------------------------------------------
--
-- Images.elm
-- Interact with the js/images.js port code.
-- Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE
--
----------------------------------------------------------------------


port module Images exposing (subImage)


port imagesIn : Command -> Cmd msg


port imagesOut : (ImagesOut -> msg) -> Sub msg


{-| The command sent to the JS code.
-}
type alias Command =
    { command : String
    , args : Args
    }


type alias Args =
    { url : String
    , left : Int
    , top : Int
    , bottom : Int
    , right : Int
    }


{-| Sent from the JS code to the imagesOut port.
-}
type alias ImagesOut =
    { command : Command
    , url : String
    }


{-| Take a portion of an existing image.
The image comes in as a URL string, and the result is another URL string.
-}
subImage : String -> Int -> Int -> Int -> Int -> Cmd msg
subImage urlIn left top right bottom =
    let
        args =
            { url = urlIn
            , left = left
            , top = top
            , right = right
            , bottom = bottom
            }

        command =
            { command = strings.subImage
            , args = args
            }
    in
    imagesIn command


strings =
    { subImage = "subImage"
    }
