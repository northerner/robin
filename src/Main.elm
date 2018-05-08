module Main exposing (..)

import Html exposing (Html, text, div, h1, img, button, p)
import Html.Events exposing (onClick)
import OAuth
import OAuth.Implicit
import Navigation
import Http
import Json.Decode exposing (int, string, float, Decoder)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


---- MODEL ----


type alias Model =
    { token: Maybe OAuth.Token
    , config: Config
    , track: Maybe Track
    }

type alias Config =
    { spotify_client_id: String }

type alias Track =
    { name: String
    , uri: String
    }

type alias Playing = { track: Track }

playingDecoder : Decoder Playing
playingDecoder =
    decode Playing
        |> required "item" trackDecoder


trackDecoder : Decoder Track
trackDecoder =
    decode Track
        |> required "name" string
        |> required "uri" string

init : Config -> Navigation.Location -> ( Model, Cmd Msg )
init config location =
    case OAuth.Implicit.parse location of
        Ok { token } ->
            ( { token = Just token, config = config, track = Nothing }, Cmd.none )
        Err _ ->
            ( { token = Nothing, config = config, track = Nothing }, Cmd.none )


---- UPDATE ----


type Msg
    = NoOp
    | Authorize
    | Control (Control)
    | ControlResponse (Result Http.Error String)
    | GetPlaying
    | PlayingResponse (Result Http.Error Playing)


type Control
    = Play
    | Pause

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            model ! []

        Authorize ->
            model
                ! [ OAuth.Implicit.authorize
                        { clientId = model.config.spotify_client_id
                        , redirectUri = "http://localhost:3000"
                        , responseType = OAuth.Token -- Use the OAuth.Token response type
                        , scope = [ "user-modify-playback-state", "user-read-playback-state" ]
                        , state = Nothing
                        , url = "https://accounts.spotify.com/authorize"
                        }
                  ]

        Control control ->
            case model.token of
                Just token ->
                    updateControl control model token
                Nothing ->
                    model ! []


        ControlResponse (Ok resp) ->
            model ! []

        ControlResponse (Err _) ->
            model ! []

        GetPlaying ->
            case model.token of
                Just token ->
                    let
                        req =
                            Http.request
                                { method = "GET"
                                , body = Http.emptyBody
                                , headers = OAuth.use token []
                                , withCredentials = False
                                , url = "https://api.spotify.com/v1/me/player/currently-playing"
                                , expect = Http.expectJson playingDecoder
                                , timeout = Nothing
                                }
                    in
                        model ! [Http.send PlayingResponse req]
                Nothing ->
                  model ! []

        PlayingResponse (Ok playing) ->
            { model | track = Just playing.track } ! []

        PlayingResponse (Err _) ->
            model ! []


updateControl : Control -> Model -> OAuth.Token -> ( Model, Cmd Msg )
updateControl control model token =
    case control of
        Play ->
            let
                req = controlRequest "play" token
            in
                model ! [Http.send ControlResponse req]

        Pause ->
            let
                req = controlRequest "pause" token
            in
                model ! [Http.send ControlResponse req]


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
    let
        controls =
            case model.token of
                Nothing ->
                    [ button [ onClick Authorize ] [ text "Sign in" ] ]
                _ ->
                    [ button [ onClick (Control Play) ] [ text "Play" ]
                    , button [ onClick (Control Pause) ] [ text "Pause" ] ]
        playing =
            case model.track of
                Just track ->
                    [ p [ ] [ text track.name ] ]
                Nothing ->
                    [ p [ onClick GetPlaying ] [ text "Click for track name" ] ]
    in
      div []
          [ h1 [] [ text "Robin" ]
          , div [] controls
          , div [] playing
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
