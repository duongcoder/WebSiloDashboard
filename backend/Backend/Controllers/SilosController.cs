using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.JsonPatch;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;
using Backend.Hubs;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SilosController : ControllerBase
    {
        private readonly SiloDbContext _context;
        private readonly IHubContext<SiloHub> _hubContext;

        public SilosController(SiloDbContext context, IHubContext<SiloHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        // GET: api/silos
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Silo>>> GetSilos()
        {
            return await _context.Silos.ToListAsync();
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Silo>> GetSilo(string id)
        {
            var silo = await _context.Silos.FindAsync(id);
            if (silo == null) return NotFound();
            return silo;
        }

        [HttpPost]
        public async Task<ActionResult<Silo>> CreateSilo(Silo silo)
        {
            _context.Silos.Add(silo);
            await _context.SaveChangesAsync();

            var silos = await _context.Silos.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);

            return CreatedAtAction(nameof(GetSilo), new { id = silo.Id }, silo);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateSilo(string id, Silo silo)
        {
            if (id != silo.Id) return BadRequest();

            _context.Entry(silo).State = EntityState.Modified;
            try
            {
                await _context.SaveChangesAsync();

                var silos = await _context.Silos.ToListAsync();
                await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!_context.Silos.Any(e => e.Id == id)) return NotFound();
                throw;
            }

            return NoContent();
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSilo(string id)
        {
            var silo = await _context.Silos.FindAsync(id);
            if (silo == null) return NotFound();

            _context.Silos.Remove(silo);
            await _context.SaveChangesAsync();

            var silos = await _context.Silos.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);

            return NoContent();
        }

        [HttpPatch("{id}")]
        public async Task<IActionResult> PatchSilo(string id, [FromBody] JsonPatchDocument<Silo> patchDoc)
        {
            if (patchDoc == null) return BadRequest();

            var silo = await _context.Silos.FindAsync(id);
            if (silo == null) return NotFound();

            patchDoc.ApplyTo(silo);
            await _context.SaveChangesAsync();

            var silos = await _context.Silos.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);

            return NoContent();
        }
    }
}
