namespace GameOfLife3DWeb.NET.Engine;

public sealed class GameState
{
    public int GridSize { get; init; }
    public bool Toroidal { get; init; }
    public string RuleName { get; init; } = "conway";
    public int[]? BirthRule { get; init; }
    public int[]? SurvivalRule { get; init; }
    public int GenerationCount { get; init; }
    public bool[]? Gen0Cells { get; init; }
}
