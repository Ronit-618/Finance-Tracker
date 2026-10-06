/// Shared "Me" label and self-name check for loans.
///
/// Every loan involves the user: either the user borrowed (From = other person,
/// To = Me) or lent (To = other person, From = Me). "Me" is a display-only
/// label for the empty side — it is never stored in the database.
const String kMeLabel = 'Me';

bool isMeValue(String value) {
  final v = value.trim().toLowerCase();
  return v == 'me' || v == 'myself' || v == 'self';
}
