using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Backend.Data;
using Backend.Models;
using Microsoft.AspNetCore.SignalR;
using Backend.Hubs;

namespace Backend.Controllers
{
    using BackendModelsController = Backend.Models.Controller;

    [ApiController]
    [Route("api/[controller]")]
    public class ControllersController : ControllerBase
    {
        private readonly SiloDbContext _context;
        private readonly IHubContext<SiloHub> _hubContext;

        public ControllersController(SiloDbContext context, IHubContext<SiloHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        // GET: api/controllers
        [HttpGet]
        public async Task<ActionResult<IEnumerable<BackendModelsController>>> GetControllers()
        {
            return await _context.Controllers.ToListAsync();
        }

        // GET: api/controllers/{id}
        [HttpGet("{id}")]
        public async Task<ActionResult<BackendModelsController>> GetController(string id)
        {
            var controller = await _context.Controllers.FindAsync(id);
            if (controller == null) return NotFound();
            return controller;
        }

        // POST: api/controllers
        [HttpPost]
        public async Task<ActionResult<BackendModelsController>> PostController(BackendModelsController controller)
        {
            _context.Controllers.Add(controller);
            await _context.SaveChangesAsync();

            var controllers = await _context.Controllers.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateControllers", controllers);

            return CreatedAtAction(nameof(GetController), new { id = controller.ControllerId }, controller);
        }

        // PUT: api/controllers/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> PutController(string id, BackendModelsController controller)
        {
            if (id != controller.Id) return BadRequest();

            _context.Entry(controller).State = EntityState.Modified;
            await _context.SaveChangesAsync();

            var controllers = await _context.Controllers.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateControllers", controllers);

            return NoContent();
        }

        // DELETE: api/controllers/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteController(string id)
        {
            var controller = await _context.Controllers.FindAsync(id);
            if (controller == null) return NotFound();

            _context.Controllers.Remove(controller);
            await _context.SaveChangesAsync();

            var controllers = await _context.Controllers.ToListAsync();
            await _hubContext.Clients.All.SendAsync("UpdateControllers", controllers);

            return NoContent();
        }
    }
}
