module Main exposing (..)

import Html exposing (Html, text, div, h1, img, button)
import Html.Events exposing (onClick)
import OAuth
import OAuth.Implicit
import Navigation
import Http


---- MODEL ----


type alias Model =
    { token: Maybe OAuth.Token, config: Config }

type alias Config =
    { spotify_client_id: String }

init : Config -> Navigation.Location -> ( Model, Cmd Msg )
init config location =
    case OAuth.Implicit.parse location of
        Ok { token } ->
            ( { token = Just token, config = config }, Cmd.none )
        Err _ ->
            ( { token = Nothing, config = config }, Cmd.none )


---- UPDATE ----


type Msg
    = NoOp
    | Authorize
    | Play
    | Pause
    | ControlResponse (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Authorize ->
            model
                ! [ OAuth.Implicit.authorize
                        { clientId = model.config.spotify_client_id
                        , redirectUri = "http://localhost:3000/play"
                        , responseType = OAuth.Token -- Use the OAuth.Token response type
                        , scope = [ "user-modify-playback-state" ]
                        , state = Nothing
                        , url = "https://accounts.spotify.com/authorize"
                        }
                  ]

        Play ->
            case model.token of
                Just token ->
                    let
                        req = controlRequest "play" token
                    in
                        model ! [Http.send ControlResponse req]

                Nothing ->
                    model ! []

        Pause ->
            case model.token of
                Just token ->
                    let
                        req = controlRequest "pause" token
                    in
                        model ! [Http.send ControlResponse req]

                Nothing ->
                    model ! []

        ControlResponse (Ok resp) ->
            model ! []

        ControlResponse (Err _) ->
            model ! []

controlRequest : String -> OAuth.Token -> Http.Request String
controlRequest action token =
    Http.request
        { method = "PUT"
        , body = Http.emptyBody
        , headers = OAuth.use token []
        , withCredentials = False
        , url = "https://api.spotify.com/v1/me/player/" ++ action
        , expect = Http.expectString
        , timeout = Nothing
        }


---- VIEW ----


view : Model -> Html Msg
view model =
    let controls =
        case model.token of
            Nothing ->
                [ button [ onClick Authorize ] [ text "Sign in" ] ]
            _ ->
                [ button [ onClick Play ] [ text "Play" ]
                , button [ onClick Pause ] [ text "Pause" ] ]
    in
      div []
          [ h1 [] [ text "Robin" ]
          , div [] controls
          ]



---- PROGRAM ----


main : Program Config Model Msg
main =
    Navigation.programWithFlags
        (always NoOp)
        { view = view
        , init = init
        , update = update
        , subscriptions = always Sub.none
        }
