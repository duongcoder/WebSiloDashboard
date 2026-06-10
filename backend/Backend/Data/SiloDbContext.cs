using Microsoft.EntityFrameworkCore;
using Backend.Models;

namespace Backend.Data
{
    public class SiloDbContext : DbContext
    {
        public SiloDbContext(DbContextOptions<SiloDbContext> options)
            : base(options)
        {
        }

        public DbSet<Silo> Silos { get; set; } = null!;
    }
}
