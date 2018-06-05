module View exposing (..)

import Model exposing (Model, Config, Track)
import Update exposing (..)

import Html.Styled.Events exposing (onClick, onInput)
import Css exposing (..)
import Css.Colors as Colors
import Html.Styled exposing (styled, Html, Attribute, text, div, h1, h2, img, button, p, input, span)
import Html.Styled.Attributes exposing (css, href, src, style, disabled, placeholder, type_)


theme : { secondary : Color, primary : Color }
theme =
    { primary = hex "4fc08d"
    , secondary = rgb 250 240 230
    }

btn : List (Html.Styled.Attribute msg) -> List (Html.Styled.Html msg) -> Html.Styled.Html msg
btn =
    styled Html.Styled.button
        [ margin (em 0.5)
        , border3 (px 1) solid theme.primary
        , borderRadius (em 2)
        , padding2 (em 0.75) (em 2)
        , backgroundColor Colors.white
        , hover
            [ backgroundColor theme.primary
            , color (rgb 250 250 250)
            ]
        ]

view : Model -> Html Msg
view model =
    let
        toCssUrl url =
            "url(" ++ url ++ ")"

        controls =
            case (model.token, model.track) of
                (Nothing, Nothing) ->
                    [ btn [ onClick Authorize ] [ text "Sign in with Spotify" ] ]
                (_, Just track) ->
                    [ div [] [ btn [ onClick (Control Play) ] [ text "Play" ]
                             , btn [ onClick (Control Pause) ] [ text "Pause" ]
                             ] ]
                _ ->
                    []

        progress track =
            styled div [ height (px 2)
                       , width (vw 100)
                       , backgroundColor Colors.black
                       ] [] [ styled div [ height (px 2)
                                         , width (vw ((track.progressMs / track.durationMs) * 100))
                                         , backgroundColor theme.primary
                                         ] [] []
                       ]

        playing =
            case model.track of
                Just track ->
                    [ p [] [ text (track.artist ++ " - " ++ track.title) ]
                    , p [] [ progress track ]
                    , img [ src track.albumCoverUrl ] []]
                Nothing ->
                    []

        admin =
            case model.user of
                Just user ->
                    [ div [] [ input [ type_ "text", placeholder "Spotify track ID", onInput SetTrackURI ] []
                             , btn [ onClick (Broadcast model.trackURI) ] [ text "Play this!" ] ] ]
                _ ->
                    [ btn [ onClick SignInToFirebase ] [ text "Sign in to DJ" ] ]

        channelButton channel =
            btn [ onClick (SwitchChannel channel) ] [ text channel.name ]

        channels =
            case (model.channels.active, model.channels.inactive) of
                (Nothing, []) ->
                    [ btn [ onClick GetChannels ] [ text "Get channels" ] ]

                (Nothing, inactive) ->
                    [ span [] [ text "Channels" ] ]
                    ++ List.map channelButton inactive

                (Just active, inactive) ->
                    [ span [] [ text "Channels" ] ]
                    ++ List.map channelButton inactive
                    ++ [ styled span [ textDecoration underline ] [] [ text ("Tuned to: " ++ active.name) ] ]

    in
      styled div [] []
          [ div [] channels
          , h1 [] [ text "Robin" ]
          , div [] controls
          , div [] admin
          , div [] playing
          ]


