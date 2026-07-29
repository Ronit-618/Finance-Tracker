using System.Reflection;
using BSDateConverter;
var methods = typeof(DateConverter).GetMethods(BindingFlags.Public | BindingFlags.Static);
foreach (var m in methods.OrderBy(m => m.Name))
{
    var parms = string.Join(", ", m.GetParameters().Select(p => $"{p.ParameterType.Name} {p.Name}"));
    Console.WriteLine($"{m.ReturnType.Name} {m.Name}({parms})");
}
