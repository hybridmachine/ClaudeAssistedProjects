using GameOfLife3DWeb.NET.Engine;
using Xunit;

namespace GameOfLife3DWeb.NET.Tests.Engine;

public sealed class GameEngineTests
{
    [Fact]
    public void ComputeSingleGeneration_UsesToroidalWrappingWhenEnabled()
    {
        var engine = new GameEngine(5);
        var pattern = new bool[5, 5];
        pattern[0, 0] = true;
        pattern[0, 4] = true;
        pattern[4, 0] = true;

        engine.InitializeFromPattern(pattern);
        engine.SetToroidal(true);

        bool advanced = engine.ComputeSingleGeneration();

        Assert.True(advanced);
        Assert.True(engine.GetGeneration(1)!.Cells[4, 4]);
    }

    [Fact]
    public void ComputeSingleGeneration_DoesNotWrapWhenToroidalDisabled()
    {
        var engine = new GameEngine(5);
        var pattern = new bool[5, 5];
        pattern[0, 0] = true;
        pattern[0, 4] = true;
        pattern[4, 0] = true;

        engine.InitializeFromPattern(pattern);
        engine.SetToroidal(false);

        bool advanced = engine.ComputeSingleGeneration();

        Assert.True(advanced);
        Assert.False(engine.GetGeneration(1)!.Cells[4, 4]);
    }

    [Fact]
    public void SetRule_HighLifeAppliesExpectedBirthBehavior()
    {
        var pattern = new bool[3, 3];
        pattern[0, 1] = true;
        pattern[0, 2] = true;
        pattern[1, 0] = true;
        pattern[1, 2] = true;
        pattern[2, 0] = true;
        pattern[2, 1] = true;

        var conway = new GameEngine(3);
        conway.InitializeFromPattern(pattern);
        conway.ComputeSingleGeneration();

        var highLife = new GameEngine(3);
        highLife.SetRule("highlife");
        highLife.InitializeFromPattern(pattern);
        highLife.ComputeSingleGeneration();

        Assert.False(conway.GetGeneration(1)!.Cells[1, 1]);
        Assert.True(highLife.GetGeneration(1)!.Cells[1, 1]);
        Assert.Equal("highlife", highLife.RuleName);
    }

    [Fact]
    public void SetCellInGen0_TruncatesFutureGenerations()
    {
        var engine = new GameEngine(5);
        var pattern = new bool[5, 5];
        pattern[2, 1] = true;
        pattern[2, 2] = true;
        pattern[2, 3] = true;

        engine.InitializeFromPattern(pattern);
        engine.ComputeSingleGeneration();
        engine.ComputeSingleGeneration();
        Assert.True(engine.GenerationCount > 1);

        engine.SetCellInGen0(0, 0, true);

        Assert.Equal(1, engine.GenerationCount);
        Assert.True(engine.GetGeneration(0)!.Cells[0, 0]);
    }

    [Fact]
    public void ExportImport_RoundTripsStateAndGenerationCount()
    {
        var original = new GameEngine(5);
        var pattern = new bool[5, 5];
        pattern[1, 2] = true;
        pattern[2, 2] = true;
        pattern[3, 2] = true;

        original.SetToroidal(false);
        original.SetRule("highlife");
        original.InitializeFromPattern(pattern);
        original.ComputeSingleGeneration();
        original.ComputeSingleGeneration();

        var exported = original.ExportState();
        var imported = new GameEngine(1);

        imported.ImportState(exported);

        Assert.Equal(original.GridSize, imported.GridSize);
        Assert.Equal(original.IsToroidal, imported.IsToroidal);
        Assert.Equal(original.RuleName, imported.RuleName);
        Assert.Equal(original.GenerationCount, imported.GenerationCount);

        for (int i = 0; i < imported.GenerationCount; i++)
        {
            AssertGridsEqual(original.GetGeneration(i)!.Cells, imported.GetGeneration(i)!.Cells);
        }
    }

    [Fact]
    public void ImportState_ThrowsForInvalidGen0CellLength()
    {
        var state = new GameState
        {
            GridSize = 4,
            Toroidal = true,
            RuleName = "conway",
            GenerationCount = 1,
            Gen0Cells = [true, false, true],
        };

        var engine = new GameEngine(1);

        var ex = Assert.Throws<ArgumentException>(() => engine.ImportState(state));
        Assert.Contains("Serialized grid length", ex.Message);
    }

    private static void AssertGridsEqual(bool[,] expected, bool[,] actual)
    {
        Assert.Equal(expected.GetLength(0), actual.GetLength(0));
        Assert.Equal(expected.GetLength(1), actual.GetLength(1));

        for (int x = 0; x < expected.GetLength(0); x++)
        {
            for (int y = 0; y < expected.GetLength(1); y++)
            {
                Assert.Equal(expected[x, y], actual[x, y]);
            }
        }
    }
}
