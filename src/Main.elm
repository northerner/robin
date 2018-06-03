port module Main exposing (..)

import Model exposing (Model, Config, Track)
import Update exposing (..)
import View exposing (view)

import OAuth.Implicit
import Task exposing (Task)
import Navigation
import Process
import Time
import OutsideInfo exposing (..)
import Html.Styled exposing (toUnstyled)


init : Config -> Navigation.Location -> ( Model, Cmd Msg )
init config location =
    case OAuth.Implicit.parse location of
        Ok { token, expiresIn } ->
            let
                model = { token = Just token
                        , config = config
                        , track = Nothing
                        , trackURI = Nothing
                        , user = Nothing }

                timeoutIn =
                    case expiresIn of
                        Just timeout -> toFloat timeout
                        _ -> 3600.0

                startAuthTimeout =
                    Process.sleep (Time.second * timeoutIn)
                    |> Task.perform (always RedirectToSignin)

                startPlayingTimeout =
                    Task.perform (always GetPlaying) (Task.succeed ())

            in
                (model , Cmd.batch [ startAuthTimeout, startPlayingTimeout ] )
        Err _ ->
            ( { token = Nothing
              , config = config
              , track = Nothing
              , trackURI = Nothing
              , user = Nothing
              } , Cmd.none )


-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.track of
              Just track ->
                  case track.isPlaying of
                      True ->
                          Time.every (Time.second) Tick
                      _ ->
                          Sub.none
              _ ->
                  Sub.none
        ,  getInfoFromOutside Outside LogErr
        ]


---- PROGRAM ----

main : Program Config Model Msg
main =
    Navigation.programWithFlags
        (always NoOp)
        { view = view >> toUnstyled
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
