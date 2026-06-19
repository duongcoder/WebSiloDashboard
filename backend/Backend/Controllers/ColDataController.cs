using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;

namespace Backend.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ColDataController : ControllerBase
    {
        private readonly SiloDbContext _context;

        public ColDataController(SiloDbContext context)
        {
            _context = context;
        }

        // GET: api/ColData
        [HttpGet]
        public async Task<ActionResult<IEnumerable<ColData>>> GetColData()
        {
            return await _context.ColData
                .OrderBy(c => c.RecordDate)
                .ToListAsync();
        }

        // GET: api/ColData/5
        [HttpGet("{id}")]
        public async Task<ActionResult<ColData>> GetColData(int id)
        {
            var colData = await _context.ColData.FindAsync(id);
            if (colData == null) return NotFound();
            return colData;
        }

        // POST: api/ColData
        [HttpPost]
        public async Task<ActionResult<ColData>> CreateColData(ColData colData)
        {
            _context.ColData.Add(colData);
            await _context.SaveChangesAsync();
            return CreatedAtAction(nameof(GetColData), new { id = colData.Id }, colData);
        }

        // PUT: api/ColData/5
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateColData(int id, ColData colData)
        {
            if (id != colData.Id) return BadRequest();

            _context.Entry(colData).State = EntityState.Modified;
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!_context.ColData.Any(e => e.Id == id)) return NotFound();
                throw;
            }

            return NoContent();
        }

        // DELETE: api/ColData/5
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteColData(int id)
        {
            var colData = await _context.ColData.FindAsync(id);
            if (colData == null) return NotFound();

            _context.ColData.Remove(colData);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
