# The .NET 8 (and ASP.NET Core 8) runtime, next to the SDK from ../dotnet, so
# net8.0 projects run and test. Building them needs nothing extra -- SDK 10
# builds for net8.0 -- but `dotnet run` and `dotnet test` start the app on
# its own target runtime. The runtime alone is a fraction of SDK 8 (about
# 190 MB of closure against 740).
#
# A bridge, not a fixture: .NET 8 support ends 10 November 2026. Once a
# project targets net10.0 everywhere, drop this part from its imports.
{ pkgs, ... }:

{
  shared.dotnet.runtimes = [ pkgs.dotnetCorePackages.aspnetcore_8_0 ];
}
