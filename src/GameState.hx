package ;
//{
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display3D.Context3DCompareMode;
import flash.display3D.Context3DStencilAction;
import flash.display3D.Context3DTriangleFace;
import flash.filters.BitmapFilter;
import flash.filters.BlurFilter;
import flash.geom.Point;
import flash.Lib;
import flash.ui.Keyboard;
import flash.utils.JSON;
import flash.Vector;
import graphite.GObjectContainer;
import graphite.GPane;
import graphite.GSlider;
import graphite.io.BinaryLoader;
import haxe.PosInfos;
import hxblit.HxBlit;
import refraction.control.DampingComponent;
import refraction.control.KeyControlComponent;
import refraction.control.RotationControlComponent;
import refraction.control.RotationFollowComponent;
import refraction.control.WayPointFollowComponent;
import refraction.core.Application;
import refraction.core.Entity;
import refraction.core.State;
import refraction.display.BitmapComponent;
import refraction.display.BlitComponent;
import refraction.display.BlitComponentB;
import refraction.display.BlitComponentC;
import refraction.display.Canvas;
import refraction.display.Surface2RenderComponentC;
import refraction.ds2d.DS2D;
import refraction.ds2d.LightSource;
import refraction.ds2d.Polygon;
import refraction.generic.PositionComponent;
import refraction.generic.TimeRemoverComponent;
import refraction.generic.TransformComponent;
import refraction.generic.VelocityComponent;
import refraction.systems.SpacingSystem;
import refraction.tile.Surface2TileRenderComponent;
import refraction.tile.TileCollisionComponent;
import refraction.tile.Tilemap;
import refraction.core.SubSystem;
import refraction.tile.TilemapDataComponent;
import refraction.tile.TilemapUtils;
//}
/**
 * ...
 * @author worldedit
 */

class GameState extends State
{

	private var TILES:BitmapData;
	private var binaryLoader:BinaryLoader;
	private var paused:Bool;
	
	public var tilemap:Tilemap;
	public var canvas:Canvas;
	public var offScreenBuffer:BitmapData;
	
	private var u:Int;
	private var lastP:Bool;
	
	public var blitSystemA:SubSystem<BlitComponent>;
	public var blitSystem:SubSystem<BlitComponentB>;
	public var blitSystemC:SubSystem<BlitComponentC>;
	public var s2rendersystem:SubSystem<Surface2RenderComponentC>;
	public var dampingSystem:SubSystem<DampingComponent>;
	public var controlComponent:KeyControlComponent;
	public var collisionSystem:SubSystem<TileCollisionComponent>;
	public var rotationComponent:RotationControlComponent;
	public var rotfollowSystem:SubSystem<RotationFollowComponent>;
	public var velocitySystem:SubSystem<VelocityComponent>;
	public var animationControl:AnimationControlComponent;
	public var projectileSystem:SubSystem<LineProjectileComponent>;
	public var bulletRenderSystem:SubSystem<BulletRender>;
	public var enemyCollideSystem:SubSystem<EnemyCollideComponent>;
	public var warpSystem:SubSystem<WarpComponent>;
	public var itemSystem:SubSystem<ItemComponent>;
	public var timeremoverSystem:SubSystem<TimeRemoverComponent>;
	public var lightControlSystem:SubSystem<LightControlComponent>;
	public var spacingSystem:SpacingSystem;
	public var spawnSystem:SubSystem<Spawner>;
	public var inventory:InventoryComponent;
	public var inventoryRender:ItemRenderComponent;
	public var shadowSystem:DS2D;
	public var strength:GSlider;
	public var ambience:GSlider;
	public var waypointfollowSystem:SubSystem<WayPointFollowComponent>;
	public var s2tilemaprender:Surface2TileRenderComponent;
	public var tilemapdata:TilemapDataComponent;
	public var fireSystem:SubSystem<FireComponent>;
	
	public var debugPane:GPane;
	
	public var player:Entity;
	public var healthBar:HealthBar;
	public var playerCollide:PlayerCollideComponent;
	
	public var menu:GameMenu;
	
	public function new() 
	{
		super(); 
	}
	
	override public function load():Void 
	{
		TILES = new Tiles(0, 0);
		
		canvas = new Canvas(400, 200, 2);
		offScreenBuffer = new BitmapData(400, 300);
		
		paused = true;
		
		HxBlit.init(start,HxBlit.nbpo2(800),HxBlit.nbpo2(400),2);
		
		TextPrompt.init();
		
		Application.stage.frameRate = 30;
	}
	
	private function start() 
	{
		initSystems();
		
		menu = new GameMenu();
		Application.stage.addChild(menu);
		//menu.visible = false;
	}
	
	public function loadGame():Void
	{
		loadLevel('bloodstrike_zm.json');
	}
	
	private function initSystems():Void
	{
		blitSystem = new SubSystem<BlitComponentB>();
		dampingSystem = new SubSystem<DampingComponent>();
		collisionSystem = new SubSystem<TileCollisionComponent>();
		rotfollowSystem = new SubSystem<RotationFollowComponent>();
		velocitySystem = new SubSystem<VelocityComponent>();
		spacingSystem = new SpacingSystem();
		blitSystemC = new SubSystem<BlitComponentC>();
		shadowSystem = new DS2D();
		fireSystem = new SubSystem<FireComponent>();
		projectileSystem = new SubSystem<LineProjectileComponent>();
		bulletRenderSystem = new SubSystem<BulletRender>();
		enemyCollideSystem = new SubSystem<EnemyCollideComponent>();
		itemSystem = new SubSystem<ItemComponent>();
		blitSystemA = new SubSystem<BlitComponent>();
		warpSystem = new SubSystem<WarpComponent>();
		s2rendersystem = new SubSystem<Surface2RenderComponentC>();
		timeremoverSystem = new SubSystem<TimeRemoverComponent>();
		spawnSystem = new SubSystem<Spawner>();
		waypointfollowSystem = new SubSystem<WayPointFollowComponent>();
		lightControlSystem = new SubSystem<LightControlComponent>();
	}
	
	public function loadLevel(_path:String):Void
	{
		binaryLoader = new BinaryLoader();
		binaryLoader.load(_path, make);
		paused = true;
	}
	
	private function make() 
	{
		initSystems();
		TextPrompt.decay = true;
		
		Factory.init();

		
		var obj:Dynamic = JSON.parse(binaryLoader.data);
		
		Factory.createTilemapHXB(obj.data[0].length, obj.data.length, obj.tilesize, 1);
		tilemapdata.setDataIntArray(obj.data);
		
		healthBar = new HealthBar();
		healthBar.hc = new HealthComponent();
		
		Factory.createPlayer(obj.start.x, obj.start.y);
		var i:Int = -1;
		while(i++<obj.warps.length-1)
		{
			var o = obj.warps[i];
			Factory.createWarp(o.x, o.y, o.level);
		}
		i = -1;
		while (i++ < obj.zombies.length - 1)
		{
			var o = obj.zombies[i];
			Factory.createZombie(o.x, o.y);
		}
		if (obj.lights != null)
		{
		i = -1;
		while (i++ < obj.lights.length - 1)
		{
			var o = obj.lights[i];
			Factory.createLight(o.x, o.y, o.color, o.radius);
		}
		}
		
		paused = false;
		menu.visible = false;
		
		for (p in TilemapUtils.computeGeometry(tilemapdata))
		{
			shadowSystem.polygons.push(p);
		}
		
		healthBar.targetCanvas = canvas;
		
		//Factory.createItem("HKMR5", 100, 100);
		//Factory.createItem("M357", 100, 100);
		Factory.createItem("FlameThrower", 130, 100);
		Factory.createSpawn(16 + 30, 240);
		//Factory.createSpawn(624 - 30, 240);
		
		SWFProfiler.init(this);
		SWFProfiler.start();
		//SWFProfiler.show();
		
	}
	
	override public function update():Void 
	{
		canvas.clear(0x00000000);
		if (Application.keys.get(Keyboard.ESCAPE))
		{
			if (SWFProfiler.displayed)
			SWFProfiler.hide();
			else
			SWFProfiler.show();
		}
		
		if (Application.keys.get(Keyboard.P) == true && lastP == false)
		{
			menu.visible = !menu.visible;
			paused = !paused;
		}
		
		lastP = Application.keys.get(Keyboard.P);
		
		if (paused)
		{
		return;
		}
		
		if (cast(player.components.get("health_comp"),HealthComponent).value <= 0)
		{
			paused = true;
			TextPrompt.decay = false;
			TextPrompt.display("You are dead, press P to display the menu");
		}
		
		spawnSystem.update();
		
		controlComponent.update();
		
		enemyCollideSystem.update();
		
		rotfollowSystem.update();
		waypointfollowSystem.update();
		spacingSystem.update();
		dampingSystem.update();
		
		inventory.update();
		itemSystem.update();
		
		projectileSystem.update();
		velocitySystem.update();
	
		animationControl.update();

		collisionSystem.update();
		rotationComponent.update();
		
		lightControlSystem.update();
		fireSystem.update();
		
		if (playerCollide.remove != true && playerCollide.removeImmediately != true)
		{
			playerCollide.update();
		}
		
		warpSystem.update();
		timeremoverSystem.update();
	}
	
	override public function render():Void 
	{
		if (paused)
		return;
		
		//canvas.clear(0x00000000);
		
		canvas.camera.x = (cast player.components.get("pos_comp")).x - 200;
		canvas.camera.y = (cast player.components.get("pos_comp")).y - 100;
		canvas.camera.width = 400;
		canvas.camera.height = 200;
		
		HxBlit.clear(0,0,0,0,1,1);
		
		HxBlit.setShader(HxBlit.HXB_shader2, 4);
		HxBlit.HXB_shader2.mproj = HxBlit.matrix2;
		HxBlit.HXB_shader2.tex = HxBlit.atlas.texture;

		HxBlit.setBlendMode("ALPHA");
		
		//if (tilemap != null)
		s2tilemaprender.update();

		blitSystemA.update();
		blitSystemC.update();
		s2rendersystem.update();
		
		HxBlit.draw();
		
		shadowSystem.renderHXB();
		
		HxBlit.flip();
		
		bulletRenderSystem.update();
		
		healthBar.render();
		//if (playerCollide.remove != true && playerCollide.removeImmediately != true)
		{
			inventoryRender.update();
		}
		
		TextPrompt.update();
	}
	
}