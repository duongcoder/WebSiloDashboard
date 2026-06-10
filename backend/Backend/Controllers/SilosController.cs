using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;
using Microsoft.AspNetCore.SignalR;
using Backend.Hubs;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SilosController : ControllerBase
    {
        private readonly SiloDbContext _context;
        private readonly ILogger<SilosController> _logger;
        private readonly IHubContext<SiloHub> _hubContext;

        public SilosController(SiloDbContext context, ILogger<SilosController> logger, IHubContext<SiloHub> hubContext)
        {
            _context = context;
            _logger = logger;
            _hubContext = hubContext;
        }

        // GET: api/silos
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Silo>>> GetSilos()
        {
            return await _context.Silos.ToListAsync();
        }

        // GET: api/silos/Silo1
        [HttpGet("{id}")]
        public async Task<ActionResult<Silo>> GetSilo(string id)
        {
            var silo = await _context.Silos.FindAsync(id);
            if (silo == null)
            {
                return NotFound();
            }
            return silo;
        }

        // POST: api/silos
        [HttpPost]
        public async Task<ActionResult<Silo>> CreateSilo(Silo silo)
        {
            _context.Silos.Add(silo);
            await _context.SaveChangesAsync();

            // Push dữ liệu mới cho tất cả client
            var silos = await _context.Silos.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);

            return CreatedAtAction(nameof(GetSilo), new { id = silo.Id }, silo);
        }

        // PUT: api/silos/Silo1
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateSilo(string id, Silo silo)
        {
            if (id != silo.Id)
            {
                return BadRequest();
            }

            _context.Entry(silo).State = EntityState.Modified;

            try
            {
                await _context.SaveChangesAsync();

                // Push dữ liệu mới cho tất cả client
                var silos = await _context.Silos.ToListAsync();
                await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!_context.Silos.Any(e => e.Id == id))
                {
                    return NotFound();
                }
                else
                {
                    throw;
                }
            }

            return NoContent();
        }

        // DELETE: api/silos/Silo1
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSilo(string id)
        {
            var silo = await _context.Silos.FindAsync(id);
            if (silo == null)
            {
                return NotFound();
            }

            _context.Silos.Remove(silo);
            await _context.SaveChangesAsync();

            // Push dữ liệu mới cho tất cả client
            var silos = await _context.Silos.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateSilos", silos);

            return NoContent();
        }
    }
}
