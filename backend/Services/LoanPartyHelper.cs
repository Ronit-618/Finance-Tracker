namespace FinanceTracker.Api.Services;

/// <summary>
/// Every loan involves the user: either the user borrowed (From = other person,
/// To = Me) or lent (To = other person, From = Me). "Me" is a display-only label
/// for the empty side — it is never stored in the database, and a loan whose
/// typed person resolves to Me is rejected.
/// </summary>
public static class LoanPartyHelper
{
    public const string MeLabel = "Me";

    public static bool IsMe(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)) return false;
        return value.Trim().ToLowerInvariant() switch
        {
            "me" or "myself" or "self" => true,
            _ => false
        };
    }
}
