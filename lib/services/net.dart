import 'package:http/http.dart' as http;

/// Client HTTP partage par toute l'app.
///
/// Les fonctions globales `http.get` / `http.post` creent un client neuf a
/// CHAQUE appel, puis le ferment : chaque requete repayait la resolution
/// DNS et la negociation TLS (souvent 150 a 400 ms sur mobile). Un client
/// unique garde les connexions ouvertes quelques secondes et les reutilise :
/// les appels successifs au proxy (classification) et aux oEmbed d'une
/// meme plateforme partent sur une connexion deja etablie.
///
/// Aucun changement de comportement : memes requetes, memes en-tetes,
/// memes delais d'expiration (appliques par l'appelant avec `.timeout`).
class Net {
  Net._();

  static final http.Client client = http.Client();
}
