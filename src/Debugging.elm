---------------------------------------------------------------
--
-- Debugging.elm
-- The one reference to the Debug module.
-- Change this to remove it.
-- Copyright (c) 2026 Bill St. Clair <billstclair@gmail.com>
-- Some rights reserved.
-- Distributed under the MIT License
-- See LICENSE
--
----------------------------------------------------------------------


module Debugging exposing (log)

{-| The one reference to the Debug module.
Change this to remove it for shipping.
-}


{-| Ignore String and return x to remove dependence on Debug.log.
-}
log : String -> x -> x
log string x =
    -- Debug.log string x
    x
