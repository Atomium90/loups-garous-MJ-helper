/// The side a role plays for. [village] and [werewolves] are the two camps of the base game;
/// [solo] roles play for their own goal; [ambiguous] roles can change side or role during the
/// game (the Voleur, the Servante Dévouée...), so their camp is only known later.
///
/// Stored nowhere by index: add new values at the end anyway.
enum Team { village, werewolves, solo, ambiguous }
