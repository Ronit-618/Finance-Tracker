namespace FinanceTracker.Api;

public static class ConnectionStringHelper
{
    public static string Normalize(string? connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return connectionString ?? string.Empty;
        }

        var trimmed = connectionString.Trim();
        if (!trimmed.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            && !trimmed.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
        {
            return connectionString;
        }

        var uri = new Uri(trimmed);

        var builder = new Npgsql.NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.IsDefaultPort ? 5432 : uri.Port,
            Database = uri.AbsolutePath.TrimStart('/'),
            Username = uri.UserInfo.Split(':')[0],
            Password = uri.UserInfo.Contains(':') ? uri.UserInfo.Split(':', 2)[1] : ""
        };

        builder.SslMode = Npgsql.SslMode.Require;

        foreach (var pair in trimmed.Split('?').Skip(1))
        {
            foreach (var kv in pair.Split('&'))
            {
                var parts = kv.Split('=', 2);
                if (parts.Length == 2 && !string.IsNullOrWhiteSpace(parts[0]))
                {
                    try
                    {
                        builder[parts[0].Trim()] = parts[1].Trim();
                    }
                    catch
                    {
                    }
                }
            }
        }

        return builder.ConnectionString;
    }
}
