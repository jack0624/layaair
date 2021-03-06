package laya.ani.swf {
	import laya.display.Sprite;
	import laya.events.Event;
	import laya.maths.Matrix;
	import laya.net.Loader;
	import laya.net.URL;
	import laya.utils.Byte;
	
	/**
	 * 动画播放完毕后调度。
	 * @eventType Event.COMPLETE
	 */
	[Event(name = "complete", type = "laya.events.Event")]
	
	/**
	 * 播放到某标签后调度。
	 * @eventType Event.LABEL
	 */
	[Event(name = "label", type = "laya.events.Event")]
	
	/**
	 * 加载完成后调度。
	 * @eventType Event.LOADED
	 */
	[Event(name = "loaded", type = "laya.events.Event")]
	
	/**
	 * 进入帧后调度。
	 * @eventType Event.FRAME
	 */
	[Event(name = "frame", type = "laya.events.Event")]
	
	/**
	 * <p> <code>MovieClip</code> 用于播放经过工具处理后的 swf 动画。</p>
	 */
	public class MovieClip extends Sprite {
		/**@private */
		protected static var _ValueList:Array = /*[STATIC SAFE]*/ ["x", "y", "width", "height", "scaleX", "scaleY", "rotation", "alpha"];
		/**@private 数据起始位置。*/
		protected var _start:int = 0;
		/**@private 当前位置。*/
		protected var _Pos:int = 0;
		/**@private 数据。*/
		protected var _data:Byte;
		/**@private */
		protected var _curIndex:int;
		/**@private */
		protected var _playIndex:int;
		/**@private */
		protected var _playing:Boolean;
		/**@private */
		protected var _ended:Boolean = true;
		/**@private 总帧数。*/
		protected var _count:int;
		/**@private id_data起始位置表*/
		public var _ids:Object;
		/**@private id_实例表*/
		public var _idOfSprite:Array;
		/**@private 父mc*/
		public var _parentMovieClip:MovieClip;
		/**@private 需要更新的movieClip表*/
		public var _movieClipList:Array;
		/**@private */
		protected var _labels:Object;
		/**资源根目录。*/
		public var basePath:String;
		/** 播放间隔(单位：毫秒)。*/
		public var interval:int = 30;
		/**是否循环播放 */
		public var loop:Boolean;
		
		/**
		 * 创建一个 <code>MovieClip</code> 实例。
		 */
		public function MovieClip(parentMovieClip:MovieClip = null) {
			_ids = {};
			_idOfSprite = [];
			_reset();
			_playing = false;
			
			this._parentMovieClip = parentMovieClip;
			if (!parentMovieClip) {
				_movieClipList = [this];
				on(Event.DISPLAY, this, _onDisplay);
				on(Event.UNDISPLAY, this, _onDisplay);
			} else {
				_movieClipList = parentMovieClip._movieClipList;
				_movieClipList.push(this);
			}
		}
		
		/** @inheritDoc */
		override public function destroy(destroyChild:Boolean = true):void {
			clear();
			super.destroy(destroyChild);
		}
		
		private function _onDisplay():void {
			
			if (_displayInStage) Laya.timer.loop(this.interval, this, updates, null, true);
			else Laya.timer.clear(this, updates);
		
		}
		
		/**@private 更新时间轴*/
		public function updates():void {
			if (_parentMovieClip) return;
			var i:int, len:int;
			len = _movieClipList.length;
			for (i = 0; i < len; i++) {
				_movieClipList[i].update();
			}
		}
		
		/**当前播放索引。*/
		public function get index():int {
			return _playIndex;
		}
		
		public function set index(value:int):void {
			_playIndex = value;
			if (_data)
				_displayFrame(_playIndex);
			if (_labels && _labels[value]) event(Event.LABEL, _labels[value]);
		}
		
		/**
		 * 增加一个标签到index帧上，播放到此index后会派发label事件
		 * @param	label	标签名称
		 * @param	index	索引位置
		 */
		public function addLabel(label:String, index:int):void {
			if (!_labels) _labels = {};
			_labels[index] = label;
		}
		
		/**
		 * 删除某个标签
		 * @param	label 标签名字，如果label为空，则删除所有Label
		 */
		public function removeLabel(label:String):void {
			if (!label) _labels = null;
			else if (!_labels) {
				for (var name:String in _labels) {
					if (_labels[name] === label) {
						delete _labels[name];
						break;
					}
				}
			}
		}
		
		/**
		 * 帧总数。
		 */
		public function get count():int {
			return _count;
		}
		
		/**
		 * 动画的帧更新处理函数。
		 */
		public function update():void {
			if (!_data) return;
			if (!_playing) return;
			_playIndex++;
			if (_playIndex >= _count) {
				if (!this.loop) {
					_playIndex--;
					stop();
					return;
				}
				_playIndex = 0;
			}
			_parse(_playIndex);
			if (_labels && _labels[_playIndex]) event(Event.LABEL, _labels[_playIndex]);
		}
		
		/**
		 * 停止播放动画。
		 */
		public function stop():void {
			_playing = false;
		}
		
		/**
		 * 跳到某帧并停止播放动画。
		 * @param frame 要跳到的帧
		 */
		public function gotoAndStop(index:int):void {
			this.index = index;
			stop();
		}
		
		/**
		 * 清理。
		 */
		public function clear():void {
			_idOfSprite.length = 0;
			if (!_parentMovieClip) {
				Laya.timer.clear(this, updates);
				var i:int, len:int;
				len = _movieClipList.length;
				for (i = 0; i < len; i++) {
					if (_movieClipList[i] != this)
						_movieClipList[i].clear();
				}
				_movieClipList.length = 0;
			}
			
			removeChildren();
			graphics = null;
			_parentMovieClip = null;
		}
		
		/**
		 * 播放动画。
		 * @param	frameIndex 帧索引。
		 */
		public function play(index:int = -1, loop:Boolean = true):void {
			this.loop = loop;
			if (_data)
				_displayFrame(index);
			_playing = true;
		}
		
		private function _displayFrame(frameIndex:int = -1):void {
			if (frameIndex != -1) {
				if (_curIndex > frameIndex) _reset();
				_parse(frameIndex);
			}
		}
		
		private function _reset(rm:Boolean = true):void {
			if (rm && _curIndex != 1) this.removeChildren();
			_curIndex = -1;
			_Pos = _start;
		}
		
		private function _parse(frameIndex:int):void {
			var curChild:Sprite = this;
			var mc:MovieClip, sp:Sprite, key:int, type:int, tPos:int, ttype:int, ifAdd:Boolean = false;
			var _idOfSprite:Array = this._idOfSprite, _data:Byte = this._data, eStr:String;
			if (_ended) _reset();
			_data.pos = _Pos;
			_ended = false;
			_playIndex = frameIndex;
			if (_curIndex > frameIndex) _curIndex = -1;
			while ((_curIndex <= frameIndex) && (!_ended)) {
				type = _data.getUint16();
				switch (type) {
				case 12: //new MC
					key = _data.getUint16();
					tPos = _ids[_data.getUint16()];
					_Pos = _data.pos;
					_data.pos = tPos;
					if ((ttype = _data.getUint8()) == 0) {
						var pid:int = _data.getUint16();
						sp = _idOfSprite[key]
						if (!sp) {
							sp = _idOfSprite[key] = new Sprite();
							//todo：优化方向
							//sp.setSize(_data.getFloat32(),_data.getFloat32());
							//var mat:Matrix=_data._getMatrix();
							//sp.loadImage(basePath+pid+".png",mat);
							
							var spp:Sprite = new Sprite();
							spp.loadImage(basePath + pid + ".png");
							sp.addChild(spp);
							spp.size(_data.getFloat32(), _data.getFloat32());
							var mat:Matrix = _data._getMatrix();
							spp.transform = mat;
						}
						sp.alpha = 1;
					} else if (ttype == 1) {
						mc = _idOfSprite[key]
						if (!mc) {
							_idOfSprite[key] = mc = new MovieClip(this);
							mc.interval = interval;
							mc._ids = _ids;
							mc.basePath = basePath;
							mc._setData(_data, tPos);
							mc._initState();
							mc.play(0);
						}
						mc.alpha = 1;
					}
					_data.pos = _Pos;
					break;
				case 3: //addChild
					(addChild(_idOfSprite[ /*key*/_data.getUint16()]) as Sprite).zOrder = _data.getUint16();
					ifAdd = true;
					break;
				case 4: //remove
					_idOfSprite[ /*key*/_data.getUint16()].removeSelf();
					break;
				case 5: //setValue
					_idOfSprite[_data.getUint16()][_ValueList[_data.getUint16()]] = (_data.getFloat32());
					break;
				case 6: //visible
					_idOfSprite[_data.getUint16()].visible = ( /*visible*/_data.getUint8() > 0);
					break;
				case 7: //SetTransform
					sp = _idOfSprite[ /*key*/_data.getUint16()]; //.transform=mt;
					var mt:Matrix = new Matrix(_data.getFloat32(), _data.getFloat32(), _data.getFloat32(), _data.getFloat32(), _data.getFloat32(), _data.getFloat32());
					sp.transform = mt;
					break;
				case 8: //pos
					_idOfSprite[_data.getUint16()].setPos(_data.getFloat32(), _data.getFloat32());
					break;
				case 9: //size
					_idOfSprite[_data.getUint16()].setSize(_data.getFloat32(), _data.getFloat32());
					break;
				case 10: //alpha
					_idOfSprite[ /*key*/_data.getUint16()].alpha = /*alpha*/ _data.getFloat32();
					break;
				case 11: //scale
					_idOfSprite[_data.getUint16()].setScale(_data.getFloat32(), _data.getFloat32());
					break;
				case 98: //event		
					eStr = _data.getString();
					event(eStr);
					if (eStr == "stop") stop();
					break;
				case 99: //FrameBegin				
					_curIndex = _data.getUint16();
					ifAdd && this.updateOrder();
					_playing && _curIndex > _playIndex && event(Event.FRAME);
					break;
				case 100: //cmdEnd
					_count = _curIndex + 1;
					_ended = true;
					if (_playing) {
						event(Event.FRAME);
						event(Event.END);
						event(Event.COMPLETE);
					}
					_reset(false);
					break;
				}
			}
			_Pos = _data.pos;
		}
		
		/**@private */
		public function _setData(data:Byte, start:int):void {
			_data = data;
			_start = start + 3;
		}
		
		/**
		 * 资源地址。
		 */
		public function set url(path:String):void {
			load(path);
		}
		
		/**
		 * 加载资源。
		 * @param	url swf 资源地址。
		 */
		public function load(url:String):void {
			url = URL.formatURL(url);
			basePath = url.split(".swf")[0] + "/image/";
			stop();
			clear();
			_movieClipList = [this];
			var data:* = Loader.getRes(url);
			if (data) {
				_initData(data);
			} else {
				var l:Loader = new Loader();
				l.once(Event.COMPLETE, null, function(data:*):void {
					_initData(data);
				});
				l.load(url, Loader.BUFFER);
			}
		}
		
		private function _initState():void {
			_reset();
			_ended = false;
			while (!_ended) _parse(++_playIndex);
		}
		
		private function _initData(data:*):void {
			_data = new Byte(data);
			var i:int, len:int = _data.getUint16();
			for (i = 0; i < len; i++) _ids[_data.getInt16()] = _data.getInt32();
			interval = 1000 / _data.getUint16();
			_setData(_data, _ids[32767]);
			_initState();
			play(0);
			if (!_parentMovieClip) Laya.timer.loop(this.interval, this, updates, null, true);
			event(Event.LOADED);
		}
	}
}