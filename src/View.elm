module View exposing (..)

import Model exposing (Model, Config, Track)
import Update exposing (..)

import Html exposing (Html, text, div, h1, h2, img, button, p, input)
import Html.Attributes exposing (src, style, disabled, placeholder, type_)
import Html.Events exposing (onClick, onInput)


view : Model -> Html Msg
view model =
    let
        toCssUrl url =
            "url(" ++ url ++ ")"

        controls =
            case (model.token, model.track) of
                (Nothing, Nothing) ->
                    [ button [ onClick Authorize ] [ text "Sign in with Spotify" ] ]
                (_, Just track) ->
                    [ div [] [ button [ onClick (Control Previous) ] [ text "Previous" ]
                             , button [ onClick (Control Play) ] [ text "Play" ]
                             , button [ onClick (Control Pause) ] [ text "Pause" ]
                             , button [ onClick (Control Next) ] [ text "Next" ] ] ]
                _ ->
                    []

        progress track =
            text ((toString (track.progressMs / 1000)) ++ " / " ++ (toString (track.durationMs / 1000)))

        playing =
            case model.track of
                Just track ->
                    [ p [] [ text (track.artist ++ " - " ++ track.title) ]
                    , p [] [ progress track ]
                    , div [ style [ ("background", toCssUrl track.albumCoverUrl)
                                  , ("background-size", "cover")
                                  , ("background-position", "center")
                                  , ("background-repeat", "no-repeat")
                                  , ("min-height", "60vh")
                                  ]] []]
                Nothing ->
                    []

        admin =
            case model.user of
                Just user ->
                    [ div [] [ input [ type_ "text", placeholder "Spotify track ID", onInput SetTrackURI ] []
                             , button [ onClick (Broadcast model.trackURI) ] [ text "Play this!" ] ] ]
                _ ->
                    [ button [ onClick SignInToFirebase ] [ text "Sign in to DJ" ] ]

    in
      div []
          [ h1 [] [ text "Robin" ]
          , div [] controls
          , div [] admin
          , div [] playing
          ]


