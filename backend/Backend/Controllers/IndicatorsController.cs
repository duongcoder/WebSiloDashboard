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
    public class IndicatorsController : ControllerBase
    {
        private readonly SiloDbContext _context;
         private readonly IHubContext<SiloHub> _hubContext;

        public IndicatorsController(SiloDbContext context, IHubContext<SiloHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        // GET: api/Indicators
        [HttpGet]
        public async Task<ActionResult<IEnumerable<Indicator>>> GetIndicators()
        {
            return await _context.Indicators.ToListAsync();
        }

        // GET: api/Indicators/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<Indicator>> GetIndicator(string id)
        {
            var indicator = await _context.Indicators.FindAsync(id);
            if (indicator == null) return NotFound();
            return indicator;
        }

        // POST: api/Indicators
        [HttpPost]
        public async Task<ActionResult<Indicator>> PostIndicator(Indicator indicator)
        {
            _context.Indicators.Add(indicator);
            await _context.SaveChangesAsync();

            var indicators = await _context.Indicators.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateIndicators", indicators);

            return CreatedAtAction(nameof(GetIndicator), new { id = indicator.IndicatorId }, indicator);
        }

        // PUT: api/Indicators/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> PutIndicator(string id, Indicator indicator)
        {
            if (id != indicator.IndicatorId) return BadRequest();

            _context.Entry(indicator).State = EntityState.Modified;

            await _context.SaveChangesAsync();

            var indicators = await _context.Indicators.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateIndicators", indicators);

            return NoContent();
        }

        // DELETE: api/Indicators/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteIndicator(string id)
        {
            var indicator = await _context.Indicators.FindAsync(id);
            if (indicator == null) return NotFound();

            _context.Indicators.Remove(indicator);
            await _context.SaveChangesAsync();

            var indicators = await _context.Indicators.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateIndicators", indicators);

            return NoContent();
        }
    }
}
