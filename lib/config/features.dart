/// Modules activés dans cette version de l'app.
///
/// Les modules désactivés restent dans le code mais ne sont proposés nulle
/// part (pas d'entrée dans l'interface, pas de chargement de données).
/// Passer à `true` pour les réactiver.
class Features {
  Features._();

  /// Pharmacie vétérinaire : catalogue de médicaments et pharmacies à proximité.
  static const bool pharmacy = false;

  /// Petites annonces (ventes entre éleveurs). Elles passeront par le fil
  /// de la communauté.
  static const bool marketplace = false;
}
