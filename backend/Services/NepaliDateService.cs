using BSDateConverter;

namespace FinanceTracker.Api.Services;

public static class NepaliDateService
{
    public static string AdToBs(DateTime adDate) =>
        DateConverter.ConvertToBSWithName(adDate.ToString("yyyy-MM-dd"));

    public static string AdToBsShort(DateTime adDate) =>
        DateConverter.ConvertADToBS(adDate.ToString("yyyy-MM-dd"));

    public static DateTime BsToAd(int bsYear, int bsMonth, int bsDay) =>
        DateTime.Parse(DateConverter.ConvertBSToAD($"{bsYear:D4}-{bsMonth:D2}-{bsDay:D2}"));

    public static (DateTime start, DateTime end) GetBsMonthAdRange(int bsYear, int bsMonth)
    {
        var startAd = BsToAd(bsYear, bsMonth, 1);
        var nextMonthBs = bsMonth == 12 ? BsToAd(bsYear + 1, 1, 1) : BsToAd(bsYear, bsMonth + 1, 1);
        var endAd = nextMonthBs.AddDays(-1);
        return (startAd, endAd);
    }
}
