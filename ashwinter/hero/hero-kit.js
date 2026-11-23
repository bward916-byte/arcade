( function () {

	class GLTFLoader extends THREE.Loader {

		constructor( manager ) {

			super( manager );
			this.dracoLoader = null;
			this.ktx2Loader = null;
			this.meshoptDecoder = null;
			this.pluginCallbacks = [];
			this.register( function ( parser ) {

				return new GLTFMaterialsClearcoatExtension( parser );

			} );
			this.register( function ( parser ) {

				return new GLTFTextureBasisUExtension( parser );

			} );
			this.register( function ( parser ) {

				return new GLTFTextureWebPExtension( parser );

			} );
			this.register( function ( parser ) {

				return new GLTFMaterialsTransmissionExtension( parser );

			} );
			this.register( function ( parser ) {

				return new GLTFLightsExtension( parser );

			} );
			this.register( function ( parser ) {

				return new GLTFMeshoptCompression( parser );

			} );

		}

		load( url, onLoad, onProgress, onError ) {

			const scope = this;
			let resourcePath;

			if ( this.resourcePath !== '' ) {

				resourcePath = this.resourcePath;

			} else if ( this.path !== '' ) {

				resourcePath = this.path;

			} else {

				resourcePath = THREE.LoaderUtils.extractUrlBase( url );

			} // Tells the LoadingManager to track an extra item, which resolves after
			// the model is fully loaded. This means the count of items loaded will
			// be incorrect, but ensures manager.onLoad() does not fire early.


			this.manager.itemStart( url );

			const _onError = function ( e ) {

				if ( onError ) {

					onError( e );

				} else {

					console.error( e );

				}

				scope.manager.itemError( url );
				scope.manager.itemEnd( url );

			};

			const loader = new THREE.FileLoader( this.manager );
			loader.setPath( this.path );
			loader.setResponseType( 'arraybuffer' );
			loader.setRequestHeader( this.requestHeader );
			loader.setWithCredentials( this.withCredentials );
			loader.load( url, function ( data ) {

				try {

					scope.parse( data, resourcePath, function ( gltf ) {

						onLoad( gltf );
						scope.manager.itemEnd( url );

					}, _onError );

				} catch ( e ) {

					_onError( e );

				}

			}, onProgress, _onError );

		}

		setDRACOLoader( dracoLoader ) {

			this.dracoLoader = dracoLoader;
			return this;

		}

		setDDSLoader() {

			throw new Error( 'THREE.GLTFLoader: "MSFT_texture_dds" no longer supported. Please update to "KHR_texture_basisu".' );

		}

		setKTX2Loader( ktx2Loader ) {

			this.ktx2Loader = ktx2Loader;
			return this;

		}

		setMeshoptDecoder( meshoptDecoder ) {

			this.meshoptDecoder = meshoptDecoder;
			return this;

		}

		register( callback ) {

			if ( this.pluginCallbacks.indexOf( callback ) === - 1 ) {

				this.pluginCallbacks.push( callback );

			}

			return this;

		}

		unregister( callback ) {

			if ( this.pluginCallbacks.indexOf( callback ) !== - 1 ) {

				this.pluginCallbacks.splice( this.pluginCallbacks.indexOf( callback ), 1 );

			}

			return this;

		}

		parse( data, path, onLoad, onError ) {

			let content;
			const extensions = {};
			const plugins = {};

			if ( typeof data === 'string' ) {

				content = data;

			} else {

				const magic = THREE.LoaderUtils.decodeText( new Uint8Array( data, 0, 4 ) );

				if ( magic === BINARY_EXTENSION_HEADER_MAGIC ) {

					try {

						extensions[ EXTENSIONS.KHR_BINARY_GLTF ] = new GLTFBinaryExtension( data );

					} catch ( error ) {

						if ( onError ) onError( error );
						return;

					}

					content = extensions[ EXTENSIONS.KHR_BINARY_GLTF ].content;

				} else {

					content = THREE.LoaderUtils.decodeText( new Uint8Array( data ) );

				}

			}

			const json = JSON.parse( content );

			if ( json.asset === undefined || json.asset.version[ 0 ] < 2 ) {

				if ( onError ) onError( new Error( 'THREE.GLTFLoader: Unsupported asset. glTF versions >=2.0 are supported.' ) );
				return;

			}

			const parser = new GLTFParser( json, {
				path: path || this.resourcePath || '',
				crossOrigin: this.crossOrigin,
				requestHeader: this.requestHeader,
				manager: this.manager,
				ktx2Loader: this.ktx2Loader,
				meshoptDecoder: this.meshoptDecoder
			} );
			parser.fileLoader.setRequestHeader( this.requestHeader );

			for ( let i = 0; i < this.pluginCallbacks.length; i ++ ) {

				const plugin = this.pluginCallbacks[ i ]( parser );
				plugins[ plugin.name ] = plugin; // Workaround to avoid determining as unknown extension
				// in addUnknownExtensionsToUserData().
				// Remove this workaround if we move all the existing
				// extension handlers to plugin system

				extensions[ plugin.name ] = true;

			}

			if ( json.extensionsUsed ) {

				for ( let i = 0; i < json.extensionsUsed.length; ++ i ) {

					const extensionName = json.extensionsUsed[ i ];
					const extensionsRequired = json.extensionsRequired || [];

					switch ( extensionName ) {

						case EXTENSIONS.KHR_MATERIALS_UNLIT:
							extensions[ extensionName ] = new GLTFMaterialsUnlitExtension();
							break;

						case EXTENSIONS.KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS:
							extensions[ extensionName ] = new GLTFMaterialsPbrSpecularGlossinessExtension();
							break;

						case EXTENSIONS.KHR_DRACO_MESH_COMPRESSION:
							extensions[ extensionName ] = new GLTFDracoMeshCompressionExtension( json, this.dracoLoader );
							break;

						case EXTENSIONS.KHR_TEXTURE_TRANSFORM:
							extensions[ extensionName ] = new GLTFTextureTransformExtension();
							break;

						case EXTENSIONS.KHR_MESH_QUANTIZATION:
							extensions[ extensionName ] = new GLTFMeshQuantizationExtension();
							break;

						default:
							if ( extensionsRequired.indexOf( extensionName ) >= 0 && plugins[ extensionName ] === undefined ) {

								console.warn( 'THREE.GLTFLoader: Unknown extension "' + extensionName + '".' );

							}

					}

				}

			}

			parser.setExtensions( extensions );
			parser.setPlugins( plugins );
			parser.parse( onLoad, onError );

		}

	}
	/* GLTFREGISTRY */


	function GLTFRegistry() {

		let objects = {};
		return {
			get: function ( key ) {

				return objects[ key ];

			},
			add: function ( key, object ) {

				objects[ key ] = object;

			},
			remove: function ( key ) {

				delete objects[ key ];

			},
			removeAll: function () {

				objects = {};

			}
		};

	}
	/*********************************/

	/********** EXTENSIONS ***********/

	/*********************************/


	const EXTENSIONS = {
		KHR_BINARY_GLTF: 'KHR_binary_glTF',
		KHR_DRACO_MESH_COMPRESSION: 'KHR_draco_mesh_compression',
		KHR_LIGHTS_PUNCTUAL: 'KHR_lights_punctual',
		KHR_MATERIALS_CLEARCOAT: 'KHR_materials_clearcoat',
		KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS: 'KHR_materials_pbrSpecularGlossiness',
		KHR_MATERIALS_TRANSMISSION: 'KHR_materials_transmission',
		KHR_MATERIALS_UNLIT: 'KHR_materials_unlit',
		KHR_TEXTURE_BASISU: 'KHR_texture_basisu',
		KHR_TEXTURE_TRANSFORM: 'KHR_texture_transform',
		KHR_MESH_QUANTIZATION: 'KHR_mesh_quantization',
		EXT_TEXTURE_WEBP: 'EXT_texture_webp',
		EXT_MESHOPT_COMPRESSION: 'EXT_meshopt_compression'
	};
	/**
	 * Punctual Lights Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_lights_punctual
	 */

	class GLTFLightsExtension {

		constructor( parser ) {

			this.parser = parser;
			this.name = EXTENSIONS.KHR_LIGHTS_PUNCTUAL; // THREE.Object3D instance caches

			this.cache = {
				refs: {},
				uses: {}
			};

		}

		_markDefs() {

			const parser = this.parser;
			const nodeDefs = this.parser.json.nodes || [];

			for ( let nodeIndex = 0, nodeLength = nodeDefs.length; nodeIndex < nodeLength; nodeIndex ++ ) {

				const nodeDef = nodeDefs[ nodeIndex ];

				if ( nodeDef.extensions && nodeDef.extensions[ this.name ] && nodeDef.extensions[ this.name ].light !== undefined ) {

					parser._addNodeRef( this.cache, nodeDef.extensions[ this.name ].light );

				}

			}

		}

		_loadLight( lightIndex ) {

			const parser = this.parser;
			const cacheKey = 'light:' + lightIndex;
			let dependency = parser.cache.get( cacheKey );
			if ( dependency ) return dependency;
			const json = parser.json;
			const extensions = json.extensions && json.extensions[ this.name ] || {};
			const lightDefs = extensions.lights || [];
			const lightDef = lightDefs[ lightIndex ];
			let lightNode;
			const color = new THREE.Color( 0xffffff );
			if ( lightDef.color !== undefined ) color.fromArray( lightDef.color );
			const range = lightDef.range !== undefined ? lightDef.range : 0;

			switch ( lightDef.type ) {

				case 'directional':
					lightNode = new THREE.DirectionalLight( color );
					lightNode.target.position.set( 0, 0, - 1 );
					lightNode.add( lightNode.target );
					break;

				case 'point':
					lightNode = new THREE.PointLight( color );
					lightNode.distance = range;
					break;

				case 'spot':
					lightNode = new THREE.SpotLight( color );
					lightNode.distance = range; // Handle spotlight properties.

					lightDef.spot = lightDef.spot || {};
					lightDef.spot.innerConeAngle = lightDef.spot.innerConeAngle !== undefined ? lightDef.spot.innerConeAngle : 0;
					lightDef.spot.outerConeAngle = lightDef.spot.outerConeAngle !== undefined ? lightDef.spot.outerConeAngle : Math.PI / 4.0;
					lightNode.angle = lightDef.spot.outerConeAngle;
					lightNode.penumbra = 1.0 - lightDef.spot.innerConeAngle / lightDef.spot.outerConeAngle;
					lightNode.target.position.set( 0, 0, - 1 );
					lightNode.add( lightNode.target );
					break;

				default:
					throw new Error( 'THREE.GLTFLoader: Unexpected light type: ' + lightDef.type );

			} // Some lights (e.g. spot) default to a position other than the origin. Reset the position
			// here, because node-level parsing will only override position if explicitly specified.


			lightNode.position.set( 0, 0, 0 );
			lightNode.decay = 2;
			if ( lightDef.intensity !== undefined ) lightNode.intensity = lightDef.intensity;
			lightNode.name = parser.createUniqueName( lightDef.name || 'light_' + lightIndex );
			dependency = Promise.resolve( lightNode );
			parser.cache.add( cacheKey, dependency );
			return dependency;

		}

		createNodeAttachment( nodeIndex ) {

			const self = this;
			const parser = this.parser;
			const json = parser.json;
			const nodeDef = json.nodes[ nodeIndex ];
			const lightDef = nodeDef.extensions && nodeDef.extensions[ this.name ] || {};
			const lightIndex = lightDef.light;
			if ( lightIndex === undefined ) return null;
			return this._loadLight( lightIndex ).then( function ( light ) {

				return parser._getNodeRef( self.cache, lightIndex, light );

			} );

		}

	}
	/**
	 * Unlit Materials Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_unlit
	 */


	class GLTFMaterialsUnlitExtension {

		constructor() {

			this.name = EXTENSIONS.KHR_MATERIALS_UNLIT;

		}

		getMaterialType() {

			return THREE.MeshBasicMaterial;

		}

		extendParams( materialParams, materialDef, parser ) {

			const pending = [];
			materialParams.color = new THREE.Color( 1.0, 1.0, 1.0 );
			materialParams.opacity = 1.0;
			const metallicRoughness = materialDef.pbrMetallicRoughness;

			if ( metallicRoughness ) {

				if ( Array.isArray( metallicRoughness.baseColorFactor ) ) {

					const array = metallicRoughness.baseColorFactor;
					materialParams.color.fromArray( array );
					materialParams.opacity = array[ 3 ];

				}

				if ( metallicRoughness.baseColorTexture !== undefined ) {

					pending.push( parser.assignTexture( materialParams, 'map', metallicRoughness.baseColorTexture ) );

				}

			}

			return Promise.all( pending );

		}

	}
	/**
	 * Clearcoat Materials Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_clearcoat
	 */


	class GLTFMaterialsClearcoatExtension {

		constructor( parser ) {

			this.parser = parser;
			this.name = EXTENSIONS.KHR_MATERIALS_CLEARCOAT;

		}

		getMaterialType( materialIndex ) {

			const parser = this.parser;
			const materialDef = parser.json.materials[ materialIndex ];
			if ( ! materialDef.extensions || ! materialDef.extensions[ this.name ] ) return null;
			return THREE.MeshPhysicalMaterial;

		}

		extendMaterialParams( materialIndex, materialParams ) {

			const parser = this.parser;
			const materialDef = parser.json.materials[ materialIndex ];

			if ( ! materialDef.extensions || ! materialDef.extensions[ this.name ] ) {

				return Promise.resolve();

			}

			const pending = [];
			const extension = materialDef.extensions[ this.name ];

			if ( extension.clearcoatFactor !== undefined ) {

				materialParams.clearcoat = extension.clearcoatFactor;

			}

			if ( extension.clearcoatTexture !== undefined ) {

				pending.push( parser.assignTexture( materialParams, 'clearcoatMap', extension.clearcoatTexture ) );

			}

			if ( extension.clearcoatRoughnessFactor !== undefined ) {

				materialParams.clearcoatRoughness = extension.clearcoatRoughnessFactor;

			}

			if ( extension.clearcoatRoughnessTexture !== undefined ) {

				pending.push( parser.assignTexture( materialParams, 'clearcoatRoughnessMap', extension.clearcoatRoughnessTexture ) );

			}

			if ( extension.clearcoatNormalTexture !== undefined ) {

				pending.push( parser.assignTexture( materialParams, 'clearcoatNormalMap', extension.clearcoatNormalTexture ) );

				if ( extension.clearcoatNormalTexture.scale !== undefined ) {

					const scale = extension.clearcoatNormalTexture.scale; // https://github.com/mrdoob/three.js/issues/11438#issuecomment-507003995

					materialParams.clearcoatNormalScale = new THREE.Vector2( scale, - scale );

				}

			}

			return Promise.all( pending );

		}

	}
	/**
	 * Transmission Materials Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_transmission
	 * Draft: https://github.com/KhronosGroup/glTF/pull/1698
	 */


	class GLTFMaterialsTransmissionExtension {

		constructor( parser ) {

			this.parser = parser;
			this.name = EXTENSIONS.KHR_MATERIALS_TRANSMISSION;

		}

		getMaterialType( materialIndex ) {

			const parser = this.parser;
			const materialDef = parser.json.materials[ materialIndex ];
			if ( ! materialDef.extensions || ! materialDef.extensions[ this.name ] ) return null;
			return THREE.MeshPhysicalMaterial;

		}

		extendMaterialParams( materialIndex, materialParams ) {

			const parser = this.parser;
			const materialDef = parser.json.materials[ materialIndex ];

			if ( ! materialDef.extensions || ! materialDef.extensions[ this.name ] ) {

				return Promise.resolve();

			}

			const pending = [];
			const extension = materialDef.extensions[ this.name ];

			if ( extension.transmissionFactor !== undefined ) {

				materialParams.transmission = extension.transmissionFactor;

			}

			if ( extension.transmissionTexture !== undefined ) {

				pending.push( parser.assignTexture( materialParams, 'transmissionMap', extension.transmissionTexture ) );

			}

			return Promise.all( pending );

		}

	}
	/**
	 * BasisU Texture Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_basisu
	 */


	class GLTFTextureBasisUExtension {

		constructor( parser ) {

			this.parser = parser;
			this.name = EXTENSIONS.KHR_TEXTURE_BASISU;

		}

		loadTexture( textureIndex ) {

			const parser = this.parser;
			const json = parser.json;
			const textureDef = json.textures[ textureIndex ];

			if ( ! textureDef.extensions || ! textureDef.extensions[ this.name ] ) {

				return null;

			}

			const extension = textureDef.extensions[ this.name ];
			const source = json.images[ extension.source ];
			const loader = parser.options.ktx2Loader;

			if ( ! loader ) {

				if ( json.extensionsRequired && json.extensionsRequired.indexOf( this.name ) >= 0 ) {

					throw new Error( 'THREE.GLTFLoader: setKTX2Loader must be called before loading KTX2 textures' );

				} else {

					// Assumes that the extension is optional and that a fallback texture is present
					return null;

				}

			}

			return parser.loadTextureImage( textureIndex, source, loader );

		}

	}
	/**
	 * WebP Texture Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_texture_webp
	 */


	class GLTFTextureWebPExtension {

		constructor( parser ) {

			this.parser = parser;
			this.name = EXTENSIONS.EXT_TEXTURE_WEBP;
			this.isSupported = null;

		}

		loadTexture( textureIndex ) {

			const name = this.name;
			const parser = this.parser;
			const json = parser.json;
			const textureDef = json.textures[ textureIndex ];

			if ( ! textureDef.extensions || ! textureDef.extensions[ name ] ) {

				return null;

			}

			const extension = textureDef.extensions[ name ];
			const source = json.images[ extension.source ];
			let loader = parser.textureLoader;

			if ( source.uri ) {

				const handler = parser.options.manager.getHandler( source.uri );
				if ( handler !== null ) loader = handler;

			}

			return this.detectSupport().then( function ( isSupported ) {

				if ( isSupported ) return parser.loadTextureImage( textureIndex, source, loader );

				if ( json.extensionsRequired && json.extensionsRequired.indexOf( name ) >= 0 ) {

					throw new Error( 'THREE.GLTFLoader: WebP required by asset but unsupported.' );

				} // Fall back to PNG or JPEG.


				return parser.loadTexture( textureIndex );

			} );

		}

		detectSupport() {

			if ( ! this.isSupported ) {

				this.isSupported = new Promise( function ( resolve ) {

					const image = new Image(); // Lossy test image. Support for lossy images doesn't guarantee support for all
					// WebP images, unfortunately.

					image.src = 'data:image/webp;base64,UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA';

					image.onload = image.onerror = function () {

						resolve( image.height === 1 );

					};

				} );

			}

			return this.isSupported;

		}

	}
	/**
	* meshopt BufferView Compression Extension
	*
	* Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_meshopt_compression
	*/


	class GLTFMeshoptCompression {

		constructor( parser ) {

			this.name = EXTENSIONS.EXT_MESHOPT_COMPRESSION;
			this.parser = parser;

		}

		loadBufferView( index ) {

			const json = this.parser.json;
			const bufferView = json.bufferViews[ index ];

			if ( bufferView.extensions && bufferView.extensions[ this.name ] ) {

				const extensionDef = bufferView.extensions[ this.name ];
				const buffer = this.parser.getDependency( 'buffer', extensionDef.buffer );
				const decoder = this.parser.options.meshoptDecoder;

				if ( ! decoder || ! decoder.supported ) {

					if ( json.extensionsRequired && json.extensionsRequired.indexOf( this.name ) >= 0 ) {

						throw new Error( 'THREE.GLTFLoader: setMeshoptDecoder must be called before loading compressed files' );

					} else {

						// Assumes that the extension is optional and that fallback buffer data is present
						return null;

					}

				}

				return Promise.all( [ buffer, decoder.ready ] ).then( function ( res ) {

					const byteOffset = extensionDef.byteOffset || 0;
					const byteLength = extensionDef.byteLength || 0;
					const count = extensionDef.count;
					const stride = extensionDef.byteStride;
					const result = new ArrayBuffer( count * stride );
					const source = new Uint8Array( res[ 0 ], byteOffset, byteLength );
					decoder.decodeGltfBuffer( new Uint8Array( result ), count, stride, source, extensionDef.mode, extensionDef.filter );
					return result;

				} );

			} else {

				return null;

			}

		}

	}
	/* BINARY EXTENSION */


	const BINARY_EXTENSION_HEADER_MAGIC = 'glTF';
	const BINARY_EXTENSION_HEADER_LENGTH = 12;
	const BINARY_EXTENSION_CHUNK_TYPES = {
		JSON: 0x4E4F534A,
		BIN: 0x004E4942
	};

	class GLTFBinaryExtension {

		constructor( data ) {

			this.name = EXTENSIONS.KHR_BINARY_GLTF;
			this.content = null;
			this.body = null;
			const headerView = new DataView( data, 0, BINARY_EXTENSION_HEADER_LENGTH );
			this.header = {
				magic: THREE.LoaderUtils.decodeText( new Uint8Array( data.slice( 0, 4 ) ) ),
				version: headerView.getUint32( 4, true ),
				length: headerView.getUint32( 8, true )
			};

			if ( this.header.magic !== BINARY_EXTENSION_HEADER_MAGIC ) {

				throw new Error( 'THREE.GLTFLoader: Unsupported glTF-Binary header.' );

			} else if ( this.header.version < 2.0 ) {

				throw new Error( 'THREE.GLTFLoader: Legacy binary file detected.' );

			}

			const chunkContentsLength = this.header.length - BINARY_EXTENSION_HEADER_LENGTH;
			const chunkView = new DataView( data, BINARY_EXTENSION_HEADER_LENGTH );
			let chunkIndex = 0;

			while ( chunkIndex < chunkContentsLength ) {

				const chunkLength = chunkView.getUint32( chunkIndex, true );
				chunkIndex += 4;
				const chunkType = chunkView.getUint32( chunkIndex, true );
				chunkIndex += 4;

				if ( chunkType === BINARY_EXTENSION_CHUNK_TYPES.JSON ) {

					const contentArray = new Uint8Array( data, BINARY_EXTENSION_HEADER_LENGTH + chunkIndex, chunkLength );
					this.content = THREE.LoaderUtils.decodeText( contentArray );

				} else if ( chunkType === BINARY_EXTENSION_CHUNK_TYPES.BIN ) {

					const byteOffset = BINARY_EXTENSION_HEADER_LENGTH + chunkIndex;
					this.body = data.slice( byteOffset, byteOffset + chunkLength );

				} // Clients must ignore chunks with unknown types.


				chunkIndex += chunkLength;

			}

			if ( this.content === null ) {

				throw new Error( 'THREE.GLTFLoader: JSON content not found.' );

			}

		}

	}
	/**
	 * DRACO THREE.Mesh Compression Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_draco_mesh_compression
	 */


	class GLTFDracoMeshCompressionExtension {

		constructor( json, dracoLoader ) {

			if ( ! dracoLoader ) {

				throw new Error( 'THREE.GLTFLoader: No DRACOLoader instance provided.' );

			}

			this.name = EXTENSIONS.KHR_DRACO_MESH_COMPRESSION;
			this.json = json;
			this.dracoLoader = dracoLoader;
			this.dracoLoader.preload();

		}

		decodePrimitive( primitive, parser ) {

			const json = this.json;
			const dracoLoader = this.dracoLoader;
			const bufferViewIndex = primitive.extensions[ this.name ].bufferView;
			const gltfAttributeMap = primitive.extensions[ this.name ].attributes;
			const threeAttributeMap = {};
			const attributeNormalizedMap = {};
			const attributeTypeMap = {};

			for ( const attributeName in gltfAttributeMap ) {

				const threeAttributeName = ATTRIBUTES[ attributeName ] || attributeName.toLowerCase();
				threeAttributeMap[ threeAttributeName ] = gltfAttributeMap[ attributeName ];

			}

			for ( const attributeName in primitive.attributes ) {

				const threeAttributeName = ATTRIBUTES[ attributeName ] || attributeName.toLowerCase();

				if ( gltfAttributeMap[ attributeName ] !== undefined ) {

					const accessorDef = json.accessors[ primitive.attributes[ attributeName ] ];
					const componentType = WEBGL_COMPONENT_TYPES[ accessorDef.componentType ];
					attributeTypeMap[ threeAttributeName ] = componentType;
					attributeNormalizedMap[ threeAttributeName ] = accessorDef.normalized === true;

				}

			}

			return parser.getDependency( 'bufferView', bufferViewIndex ).then( function ( bufferView ) {

				return new Promise( function ( resolve ) {

					dracoLoader.decodeDracoFile( bufferView, function ( geometry ) {

						for ( const attributeName in geometry.attributes ) {

							const attribute = geometry.attributes[ attributeName ];
							const normalized = attributeNormalizedMap[ attributeName ];
							if ( normalized !== undefined ) attribute.normalized = normalized;

						}

						resolve( geometry );

					}, threeAttributeMap, attributeTypeMap );

				} );

			} );

		}

	}
	/**
	 * Texture Transform Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_texture_transform
	 */


	class GLTFTextureTransformExtension {

		constructor() {

			this.name = EXTENSIONS.KHR_TEXTURE_TRANSFORM;

		}

		extendTexture( texture, transform ) {

			texture = texture.clone();

			if ( transform.offset !== undefined ) {

				texture.offset.fromArray( transform.offset );

			}

			if ( transform.rotation !== undefined ) {

				texture.rotation = transform.rotation;

			}

			if ( transform.scale !== undefined ) {

				texture.repeat.fromArray( transform.scale );

			}

			if ( transform.texCoord !== undefined ) {

				console.warn( 'THREE.GLTFLoader: Custom UV sets in "' + this.name + '" extension not yet supported.' );

			}

			texture.needsUpdate = true;
			return texture;

		}

	}
	/**
	 * Specular-Glossiness Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_materials_pbrSpecularGlossiness
	 */

	/**
	 * A sub class of StandardMaterial with some of the functionality
	 * changed via the `onBeforeCompile` callback
	 * @pailhead
	 */


	class GLTFMeshStandardSGMaterial extends THREE.MeshStandardMaterial {

		constructor( params ) {

			super();
			this.isGLTFSpecularGlossinessMaterial = true; //various chunks that need replacing

			const specularMapParsFragmentChunk = [ '#ifdef USE_SPECULARMAP', '	uniform sampler2D specularMap;', '#endif' ].join( '\n' );
			const glossinessMapParsFragmentChunk = [ '#ifdef USE_GLOSSINESSMAP', '	uniform sampler2D glossinessMap;', '#endif' ].join( '\n' );
			const specularMapFragmentChunk = [ 'vec3 specularFactor = specular;', '#ifdef USE_SPECULARMAP', '	vec4 texelSpecular = texture2D( specularMap, vUv );', '	texelSpecular = sRGBToLinear( texelSpecular );', '	// reads channel RGB, compatible with a glTF Specular-Glossiness (RGBA) texture', '	specularFactor *= texelSpecular.rgb;', '#endif' ].join( '\n' );
			const glossinessMapFragmentChunk = [ 'float glossinessFactor = glossiness;', '#ifdef USE_GLOSSINESSMAP', '	vec4 texelGlossiness = texture2D( glossinessMap, vUv );', '	// reads channel A, compatible with a glTF Specular-Glossiness (RGBA) texture', '	glossinessFactor *= texelGlossiness.a;', '#endif' ].join( '\n' );
			const lightPhysicalFragmentChunk = [ 'PhysicalMaterial material;', 'material.diffuseColor = diffuseColor.rgb * ( 1. - max( specularFactor.r, max( specularFactor.g, specularFactor.b ) ) );', 'vec3 dxy = max( abs( dFdx( geometryNormal ) ), abs( dFdy( geometryNormal ) ) );', 'float geometryRoughness = max( max( dxy.x, dxy.y ), dxy.z );', 'material.specularRoughness = max( 1.0 - glossinessFactor, 0.0525 ); // 0.0525 corresponds to the base mip of a 256 cubemap.', 'material.specularRoughness += geometryRoughness;', 'material.specularRoughness = min( material.specularRoughness, 1.0 );', 'material.specularColor = specularFactor;' ].join( '\n' );
			const uniforms = {
				specular: {
					value: new THREE.Color().setHex( 0xffffff )
				},
				glossiness: {
					value: 1
				},
				specularMap: {
					value: null
				},
				glossinessMap: {
					value: null
				}
			};
			this._extraUniforms = uniforms;

			this.onBeforeCompile = function ( shader ) {

				for ( const uniformName in uniforms ) {

					shader.uniforms[ uniformName ] = uniforms[ uniformName ];

				}

				shader.fragmentShader = shader.fragmentShader.replace( 'uniform float roughness;', 'uniform vec3 specular;' ).replace( 'uniform float metalness;', 'uniform float glossiness;' ).replace( '#include <roughnessmap_pars_fragment>', specularMapParsFragmentChunk ).replace( '#include <metalnessmap_pars_fragment>', glossinessMapParsFragmentChunk ).replace( '#include <roughnessmap_fragment>', specularMapFragmentChunk ).replace( '#include <metalnessmap_fragment>', glossinessMapFragmentChunk ).replace( '#include <lights_physical_fragment>', lightPhysicalFragmentChunk );

			};

			Object.defineProperties( this, {
				specular: {
					get: function () {

						return uniforms.specular.value;

					},
					set: function ( v ) {

						uniforms.specular.value = v;

					}
				},
				specularMap: {
					get: function () {

						return uniforms.specularMap.value;

					},
					set: function ( v ) {

						uniforms.specularMap.value = v;

						if ( v ) {

							this.defines.USE_SPECULARMAP = ''; // USE_UV is set by the renderer for specular maps

						} else {

							delete this.defines.USE_SPECULARMAP;

						}

					}
				},
				glossiness: {
					get: function () {

						return uniforms.glossiness.value;

					},
					set: function ( v ) {

						uniforms.glossiness.value = v;

					}
				},
				glossinessMap: {
					get: function () {

						return uniforms.glossinessMap.value;

					},
					set: function ( v ) {

						uniforms.glossinessMap.value = v;

						if ( v ) {

							this.defines.USE_GLOSSINESSMAP = '';
							this.defines.USE_UV = '';

						} else {

							delete this.defines.USE_GLOSSINESSMAP;
							delete this.defines.USE_UV;

						}

					}
				}
			} );
			delete this.metalness;
			delete this.roughness;
			delete this.metalnessMap;
			delete this.roughnessMap;
			this.setValues( params );

		}

		copy( source ) {

			super.copy( source );
			this.specularMap = source.specularMap;
			this.specular.copy( source.specular );
			this.glossinessMap = source.glossinessMap;
			this.glossiness = source.glossiness;
			delete this.metalness;
			delete this.roughness;
			delete this.metalnessMap;
			delete this.roughnessMap;
			return this;

		}

	}

	class GLTFMaterialsPbrSpecularGlossinessExtension {

		constructor() {

			this.name = EXTENSIONS.KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS;
			this.specularGlossinessParams = [ 'color', 'map', 'lightMap', 'lightMapIntensity', 'aoMap', 'aoMapIntensity', 'emissive', 'emissiveIntensity', 'emissiveMap', 'bumpMap', 'bumpScale', 'normalMap', 'normalMapType', 'displacementMap', 'displacementScale', 'displacementBias', 'specularMap', 'specular', 'glossinessMap', 'glossiness', 'alphaMap', 'envMap', 'envMapIntensity', 'refractionRatio' ];

		}

		getMaterialType() {

			return GLTFMeshStandardSGMaterial;

		}

		extendParams( materialParams, materialDef, parser ) {

			const pbrSpecularGlossiness = materialDef.extensions[ this.name ];
			materialParams.color = new THREE.Color( 1.0, 1.0, 1.0 );
			materialParams.opacity = 1.0;
			const pending = [];

			if ( Array.isArray( pbrSpecularGlossiness.diffuseFactor ) ) {

				const array = pbrSpecularGlossiness.diffuseFactor;
				materialParams.color.fromArray( array );
				materialParams.opacity = array[ 3 ];

			}

			if ( pbrSpecularGlossiness.diffuseTexture !== undefined ) {

				pending.push( parser.assignTexture( materialParams, 'map', pbrSpecularGlossiness.diffuseTexture ) );

			}

			materialParams.emissive = new THREE.Color( 0.0, 0.0, 0.0 );
			materialParams.glossiness = pbrSpecularGlossiness.glossinessFactor !== undefined ? pbrSpecularGlossiness.glossinessFactor : 1.0;
			materialParams.specular = new THREE.Color( 1.0, 1.0, 1.0 );

			if ( Array.isArray( pbrSpecularGlossiness.specularFactor ) ) {

				materialParams.specular.fromArray( pbrSpecularGlossiness.specularFactor );

			}

			if ( pbrSpecularGlossiness.specularGlossinessTexture !== undefined ) {

				const specGlossMapDef = pbrSpecularGlossiness.specularGlossinessTexture;
				pending.push( parser.assignTexture( materialParams, 'glossinessMap', specGlossMapDef ) );
				pending.push( parser.assignTexture( materialParams, 'specularMap', specGlossMapDef ) );

			}

			return Promise.all( pending );

		}

		createMaterial( materialParams ) {

			const material = new GLTFMeshStandardSGMaterial( materialParams );
			material.fog = true;
			material.color = materialParams.color;
			material.map = materialParams.map === undefined ? null : materialParams.map;
			material.lightMap = null;
			material.lightMapIntensity = 1.0;
			material.aoMap = materialParams.aoMap === undefined ? null : materialParams.aoMap;
			material.aoMapIntensity = 1.0;
			material.emissive = materialParams.emissive;
			material.emissiveIntensity = 1.0;
			material.emissiveMap = materialParams.emissiveMap === undefined ? null : materialParams.emissiveMap;
			material.bumpMap = materialParams.bumpMap === undefined ? null : materialParams.bumpMap;
			material.bumpScale = 1;
			material.normalMap = materialParams.normalMap === undefined ? null : materialParams.normalMap;
			material.normalMapType = THREE.TangentSpaceNormalMap;
			if ( materialParams.normalScale ) material.normalScale = materialParams.normalScale;
			material.displacementMap = null;
			material.displacementScale = 1;
			material.displacementBias = 0;
			material.specularMap = materialParams.specularMap === undefined ? null : materialParams.specularMap;
			material.specular = materialParams.specular;
			material.glossinessMap = materialParams.glossinessMap === undefined ? null : materialParams.glossinessMap;
			material.glossiness = materialParams.glossiness;
			material.alphaMap = null;
			material.envMap = materialParams.envMap === undefined ? null : materialParams.envMap;
			material.envMapIntensity = 1.0;
			material.refractionRatio = 0.98;
			return material;

		}

	}
	/**
	 * THREE.Mesh Quantization Extension
	 *
	 * Specification: https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_mesh_quantization
	 */


	class GLTFMeshQuantizationExtension {

		constructor() {

			this.name = EXTENSIONS.KHR_MESH_QUANTIZATION;

		}

	}
	/*********************************/

	/********** INTERPOLATION ********/

	/*********************************/
	// Spline Interpolation
	// Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#appendix-c-spline-interpolation


	class GLTFCubicSplineInterpolant extends THREE.Interpolant {

		constructor( parameterPositions, sampleValues, sampleSize, resultBuffer ) {

			super( parameterPositions, sampleValues, sampleSize, resultBuffer );

		}

		copySampleValue_( index ) {

			// Copies a sample value to the result buffer. See description of glTF
			// CUBICSPLINE values layout in interpolate_() function below.
			const result = this.resultBuffer,
				values = this.sampleValues,
				valueSize = this.valueSize,
				offset = index * valueSize * 3 + valueSize;

			for ( let i = 0; i !== valueSize; i ++ ) {

				result[ i ] = values[ offset + i ];

			}

			return result;

		}

	}

	GLTFCubicSplineInterpolant.prototype.beforeStart_ = GLTFCubicSplineInterpolant.prototype.copySampleValue_;
	GLTFCubicSplineInterpolant.prototype.afterEnd_ = GLTFCubicSplineInterpolant.prototype.copySampleValue_;

	GLTFCubicSplineInterpolant.prototype.interpolate_ = function ( i1, t0, t, t1 ) {

		const result = this.resultBuffer;
		const values = this.sampleValues;
		const stride = this.valueSize;
		const stride2 = stride * 2;
		const stride3 = stride * 3;
		const td = t1 - t0;
		const p = ( t - t0 ) / td;
		const pp = p * p;
		const ppp = pp * p;
		const offset1 = i1 * stride3;
		const offset0 = offset1 - stride3;
		const s2 = - 2 * ppp + 3 * pp;
		const s3 = ppp - pp;
		const s0 = 1 - s2;
		const s1 = s3 - pp + p; // Layout of keyframe output values for CUBICSPLINE animations:
		//   [ inTangent_1, splineVertex_1, outTangent_1, inTangent_2, splineVertex_2, ... ]

		for ( let i = 0; i !== stride; i ++ ) {

			const p0 = values[ offset0 + i + stride ]; // splineVertex_k

			const m0 = values[ offset0 + i + stride2 ] * td; // outTangent_k * (t_k+1 - t_k)

			const p1 = values[ offset1 + i + stride ]; // splineVertex_k+1

			const m1 = values[ offset1 + i ] * td; // inTangent_k+1 * (t_k+1 - t_k)

			result[ i ] = s0 * p0 + s1 * m0 + s2 * p1 + s3 * m1;

		}

		return result;

	};
	/*********************************/

	/********** INTERNALS ************/

	/*********************************/

	/* CONSTANTS */


	const WEBGL_CONSTANTS = {
		FLOAT: 5126,
		//FLOAT_MAT2: 35674,
		FLOAT_MAT3: 35675,
		FLOAT_MAT4: 35676,
		FLOAT_VEC2: 35664,
		FLOAT_VEC3: 35665,
		FLOAT_VEC4: 35666,
		LINEAR: 9729,
		REPEAT: 10497,
		SAMPLER_2D: 35678,
		POINTS: 0,
		LINES: 1,
		LINE_LOOP: 2,
		LINE_STRIP: 3,
		TRIANGLES: 4,
		TRIANGLE_STRIP: 5,
		TRIANGLE_FAN: 6,
		UNSIGNED_BYTE: 5121,
		UNSIGNED_SHORT: 5123
	};
	const WEBGL_COMPONENT_TYPES = {
		5120: Int8Array,
		5121: Uint8Array,
		5122: Int16Array,
		5123: Uint16Array,
		5125: Uint32Array,
		5126: Float32Array
	};
	const WEBGL_FILTERS = {
		9728: THREE.NearestFilter,
		9729: THREE.LinearFilter,
		9984: THREE.NearestMipmapNearestFilter,
		9985: THREE.LinearMipmapNearestFilter,
		9986: THREE.NearestMipmapLinearFilter,
		9987: THREE.LinearMipmapLinearFilter
	};
	const WEBGL_WRAPPINGS = {
		33071: THREE.ClampToEdgeWrapping,
		33648: THREE.MirroredRepeatWrapping,
		10497: THREE.RepeatWrapping
	};
	const WEBGL_TYPE_SIZES = {
		'SCALAR': 1,
		'VEC2': 2,
		'VEC3': 3,
		'VEC4': 4,
		'MAT2': 4,
		'MAT3': 9,
		'MAT4': 16
	};
	const ATTRIBUTES = {
		POSITION: 'position',
		NORMAL: 'normal',
		TANGENT: 'tangent',
		TEXCOORD_0: 'uv',
		TEXCOORD_1: 'uv2',
		COLOR_0: 'color',
		WEIGHTS_0: 'skinWeight',
		JOINTS_0: 'skinIndex'
	};
	const PATH_PROPERTIES = {
		scale: 'scale',
		translation: 'position',
		rotation: 'quaternion',
		weights: 'morphTargetInfluences'
	};
	const INTERPOLATION = {
		CUBICSPLINE: undefined,
		// We use a custom interpolant (GLTFCubicSplineInterpolation) for CUBICSPLINE tracks. Each
		// keyframe track will be initialized with a default interpolation type, then modified.
		LINEAR: THREE.InterpolateLinear,
		STEP: THREE.InterpolateDiscrete
	};
	const ALPHA_MODES = {
		OPAQUE: 'OPAQUE',
		MASK: 'MASK',
		BLEND: 'BLEND'
	};
	/* UTILITY FUNCTIONS */

	function resolveURL( url, path ) {

		// Invalid URL
		if ( typeof url !== 'string' || url === '' ) return ''; // Host Relative URL

		if ( /^https?:\/\//i.test( path ) && /^\//.test( url ) ) {

			path = path.replace( /(^https?:\/\/[^\/]+).*/i, '$1' );

		} // Absolute URL http://,https://,//


		if ( /^(https?:)?\/\//i.test( url ) ) return url; // Data URI

		if ( /^data:.*,.*$/i.test( url ) ) return url; // Blob URL

		if ( /^blob:.*$/i.test( url ) ) return url; // Relative URL

		return path + url;

	}
	/**
	 * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#default-material
	 */


	function createDefaultMaterial( cache ) {

		if ( cache[ 'DefaultMaterial' ] === undefined ) {

			cache[ 'DefaultMaterial' ] = new THREE.MeshStandardMaterial( {
				color: 0xFFFFFF,
				emissive: 0x000000,
				metalness: 1,
				roughness: 1,
				transparent: false,
				depthTest: true,
				side: THREE.FrontSide
			} );

		}

		return cache[ 'DefaultMaterial' ];

	}

	function addUnknownExtensionsToUserData( knownExtensions, object, objectDef ) {

		// Add unknown glTF extensions to an object's userData.
		for ( const name in objectDef.extensions ) {

			if ( knownExtensions[ name ] === undefined ) {

				object.userData.gltfExtensions = object.userData.gltfExtensions || {};
				object.userData.gltfExtensions[ name ] = objectDef.extensions[ name ];

			}

		}

	}
	/**
	 * @param {Object3D|Material|BufferGeometry} object
	 * @param {GLTF.definition} gltfDef
	 */


	function assignExtrasToUserData( object, gltfDef ) {

		if ( gltfDef.extras !== undefined ) {

			if ( typeof gltfDef.extras === 'object' ) {

				Object.assign( object.userData, gltfDef.extras );

			} else {

				console.warn( 'THREE.GLTFLoader: Ignoring primitive type .extras, ' + gltfDef.extras );

			}

		}

	}
	/**
	 * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#morph-targets
	 *
	 * @param {BufferGeometry} geometry
	 * @param {Array<GLTF.Target>} targets
	 * @param {GLTFParser} parser
	 * @return {Promise<BufferGeometry>}
	 */


	function addMorphTargets( geometry, targets, parser ) {

		let hasMorphPosition = false;
		let hasMorphNormal = false;

		for ( let i = 0, il = targets.length; i < il; i ++ ) {

			const target = targets[ i ];
			if ( target.POSITION !== undefined ) hasMorphPosition = true;
			if ( target.NORMAL !== undefined ) hasMorphNormal = true;
			if ( hasMorphPosition && hasMorphNormal ) break;

		}

		if ( ! hasMorphPosition && ! hasMorphNormal ) return Promise.resolve( geometry );
		const pendingPositionAccessors = [];
		const pendingNormalAccessors = [];

		for ( let i = 0, il = targets.length; i < il; i ++ ) {

			const target = targets[ i ];

			if ( hasMorphPosition ) {

				const pendingAccessor = target.POSITION !== undefined ? parser.getDependency( 'accessor', target.POSITION ) : geometry.attributes.position;
				pendingPositionAccessors.push( pendingAccessor );

			}

			if ( hasMorphNormal ) {

				const pendingAccessor = target.NORMAL !== undefined ? parser.getDependency( 'accessor', target.NORMAL ) : geometry.attributes.normal;
				pendingNormalAccessors.push( pendingAccessor );

			}

		}

		return Promise.all( [ Promise.all( pendingPositionAccessors ), Promise.all( pendingNormalAccessors ) ] ).then( function ( accessors ) {

			const morphPositions = accessors[ 0 ];
			const morphNormals = accessors[ 1 ];
			if ( hasMorphPosition ) geometry.morphAttributes.position = morphPositions;
			if ( hasMorphNormal ) geometry.morphAttributes.normal = morphNormals;
			geometry.morphTargetsRelative = true;
			return geometry;

		} );

	}
	/**
	 * @param {Mesh} mesh
	 * @param {GLTF.Mesh} meshDef
	 */


	function updateMorphTargets( mesh, meshDef ) {

		mesh.updateMorphTargets();

		if ( meshDef.weights !== undefined ) {

			for ( let i = 0, il = meshDef.weights.length; i < il; i ++ ) {

				mesh.morphTargetInfluences[ i ] = meshDef.weights[ i ];

			}

		} // .extras has user-defined data, so check that .extras.targetNames is an array.


		if ( meshDef.extras && Array.isArray( meshDef.extras.targetNames ) ) {

			const targetNames = meshDef.extras.targetNames;

			if ( mesh.morphTargetInfluences.length === targetNames.length ) {

				mesh.morphTargetDictionary = {};

				for ( let i = 0, il = targetNames.length; i < il; i ++ ) {

					mesh.morphTargetDictionary[ targetNames[ i ] ] = i;

				}

			} else {

				console.warn( 'THREE.GLTFLoader: Invalid extras.targetNames length. Ignoring names.' );

			}

		}

	}

	function createPrimitiveKey( primitiveDef ) {

		const dracoExtension = primitiveDef.extensions && primitiveDef.extensions[ EXTENSIONS.KHR_DRACO_MESH_COMPRESSION ];
		let geometryKey;

		if ( dracoExtension ) {

			geometryKey = 'draco:' + dracoExtension.bufferView + ':' + dracoExtension.indices + ':' + createAttributesKey( dracoExtension.attributes );

		} else {

			geometryKey = primitiveDef.indices + ':' + createAttributesKey( primitiveDef.attributes ) + ':' + primitiveDef.mode;

		}

		return geometryKey;

	}

	function createAttributesKey( attributes ) {

		let attributesKey = '';
		const keys = Object.keys( attributes ).sort();

		for ( let i = 0, il = keys.length; i < il; i ++ ) {

			attributesKey += keys[ i ] + ':' + attributes[ keys[ i ] ] + ';';

		}

		return attributesKey;

	}

	function getNormalizedComponentScale( constructor ) {

		// Reference:
		// https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Khronos/KHR_mesh_quantization#encoding-quantized-data
		switch ( constructor ) {

			case Int8Array:
				return 1 / 127;

			case Uint8Array:
				return 1 / 255;

			case Int16Array:
				return 1 / 32767;

			case Uint16Array:
				return 1 / 65535;

			default:
				throw new Error( 'THREE.GLTFLoader: Unsupported normalized accessor component type.' );

		}

	}
	/* GLTF PARSER */


	class GLTFParser {

		constructor( json = {}, options = {} ) {

			this.json = json;
			this.extensions = {};
			this.plugins = {};
			this.options = options; // loader object cache

			this.cache = new GLTFRegistry(); // associations between Three.js objects and glTF elements

			this.associations = new Map(); // THREE.BufferGeometry caching

			this.primitiveCache = {}; // THREE.Object3D instance caches

			this.meshCache = {
				refs: {},
				uses: {}
			};
			this.cameraCache = {
				refs: {},
				uses: {}
			};
			this.lightCache = {
				refs: {},
				uses: {}
			}; // Track node names, to ensure no duplicates

			this.nodeNamesUsed = {}; // Use an THREE.ImageBitmapLoader if imageBitmaps are supported. Moves much of the
			// expensive work of uploading a texture to the GPU off the main thread.

			if ( typeof createImageBitmap !== 'undefined' && /Firefox/.test( navigator.userAgent ) === false ) {

				this.textureLoader = new THREE.ImageBitmapLoader( this.options.manager );

			} else {

				this.textureLoader = new THREE.TextureLoader( this.options.manager );

			}

			this.textureLoader.setCrossOrigin( this.options.crossOrigin );
			this.textureLoader.setRequestHeader( this.options.requestHeader );
			this.fileLoader = new THREE.FileLoader( this.options.manager );
			this.fileLoader.setResponseType( 'arraybuffer' );

			if ( this.options.crossOrigin === 'use-credentials' ) {

				this.fileLoader.setWithCredentials( true );

			}

		}

		setExtensions( extensions ) {

			this.extensions = extensions;

		}

		setPlugins( plugins ) {

			this.plugins = plugins;

		}

		parse( onLoad, onError ) {

			const parser = this;
			const json = this.json;
			const extensions = this.extensions; // Clear the loader cache

			this.cache.removeAll(); // Mark the special nodes/meshes in json for efficient parse

			this._invokeAll( function ( ext ) {

				return ext._markDefs && ext._markDefs();

			} );

			Promise.all( this._invokeAll( function ( ext ) {

				return ext.beforeRoot && ext.beforeRoot();

			} ) ).then( function () {

				return Promise.all( [ parser.getDependencies( 'scene' ), parser.getDependencies( 'animation' ), parser.getDependencies( 'camera' ) ] );

			} ).then( function ( dependencies ) {

				const result = {
					scene: dependencies[ 0 ][ json.scene || 0 ],
					scenes: dependencies[ 0 ],
					animations: dependencies[ 1 ],
					cameras: dependencies[ 2 ],
					asset: json.asset,
					parser: parser,
					userData: {}
				};
				addUnknownExtensionsToUserData( extensions, result, json );
				assignExtrasToUserData( result, json );
				Promise.all( parser._invokeAll( function ( ext ) {

					return ext.afterRoot && ext.afterRoot( result );

				} ) ).then( function () {

					onLoad( result );

				} );

			} ).catch( onError );

		}
		/**
   * Marks the special nodes/meshes in json for efficient parse.
   */


		_markDefs() {

			const nodeDefs = this.json.nodes || [];
			const skinDefs = this.json.skins || [];
			const meshDefs = this.json.meshes || []; // Nothing in the node definition indicates whether it is a THREE.Bone or an
			// THREE.Object3D. Use the skins' joint references to mark bones.

			for ( let skinIndex = 0, skinLength = skinDefs.length; skinIndex < skinLength; skinIndex ++ ) {

				const joints = skinDefs[ skinIndex ].joints;

				for ( let i = 0, il = joints.length; i < il; i ++ ) {

					nodeDefs[ joints[ i ] ].isBone = true;

				}

			} // Iterate over all nodes, marking references to shared resources,
			// as well as skeleton joints.


			for ( let nodeIndex = 0, nodeLength = nodeDefs.length; nodeIndex < nodeLength; nodeIndex ++ ) {

				const nodeDef = nodeDefs[ nodeIndex ];

				if ( nodeDef.mesh !== undefined ) {

					this._addNodeRef( this.meshCache, nodeDef.mesh ); // Nothing in the mesh definition indicates whether it is
					// a THREE.SkinnedMesh or THREE.Mesh. Use the node's mesh reference
					// to mark THREE.SkinnedMesh if node has skin.


					if ( nodeDef.skin !== undefined ) {

						meshDefs[ nodeDef.mesh ].isSkinnedMesh = true;

					}

				}

				if ( nodeDef.camera !== undefined ) {

					this._addNodeRef( this.cameraCache, nodeDef.camera );

				}

			}

		}
		/**
   * Counts references to shared node / THREE.Object3D resources. These resources
   * can be reused, or "instantiated", at multiple nodes in the scene
   * hierarchy. THREE.Mesh, Camera, and Light instances are instantiated and must
   * be marked. Non-scenegraph resources (like Materials, Geometries, and
   * Textures) can be reused directly and are not marked here.
   *
   * Example: CesiumMilkTruck sample model reuses "Wheel" meshes.
   */


		_addNodeRef( cache, index ) {

			if ( index === undefined ) return;

			if ( cache.refs[ index ] === undefined ) {

				cache.refs[ index ] = cache.uses[ index ] = 0;

			}

			cache.refs[ index ] ++;

		}
		/** Returns a reference to a shared resource, cloning it if necessary. */


		_getNodeRef( cache, index, object ) {

			if ( cache.refs[ index ] <= 1 ) return object;
			const ref = object.clone();
			ref.name += '_instance_' + cache.uses[ index ] ++;
			return ref;

		}

		_invokeOne( func ) {

			const extensions = Object.values( this.plugins );
			extensions.push( this );

			for ( let i = 0; i < extensions.length; i ++ ) {

				const result = func( extensions[ i ] );
				if ( result ) return result;

			}

			return null;

		}

		_invokeAll( func ) {

			const extensions = Object.values( this.plugins );
			extensions.unshift( this );
			const pending = [];

			for ( let i = 0; i < extensions.length; i ++ ) {

				const result = func( extensions[ i ] );
				if ( result ) pending.push( result );

			}

			return pending;

		}
		/**
   * Requests the specified dependency asynchronously, with caching.
   * @param {string} type
   * @param {number} index
   * @return {Promise<Object3D|Material|THREE.Texture|AnimationClip|ArrayBuffer|Object>}
   */


		getDependency( type, index ) {

			const cacheKey = type + ':' + index;
			let dependency = this.cache.get( cacheKey );

			if ( ! dependency ) {

				switch ( type ) {

					case 'scene':
						dependency = this.loadScene( index );
						break;

					case 'node':
						dependency = this.loadNode( index );
						break;

					case 'mesh':
						dependency = this._invokeOne( function ( ext ) {

							return ext.loadMesh && ext.loadMesh( index );

						} );
						break;

					case 'accessor':
						dependency = this.loadAccessor( index );
						break;

					case 'bufferView':
						dependency = this._invokeOne( function ( ext ) {

							return ext.loadBufferView && ext.loadBufferView( index );

						} );
						break;

					case 'buffer':
						dependency = this.loadBuffer( index );
						break;

					case 'material':
						dependency = this._invokeOne( function ( ext ) {

							return ext.loadMaterial && ext.loadMaterial( index );

						} );
						break;

					case 'texture':
						dependency = this._invokeOne( function ( ext ) {

							return ext.loadTexture && ext.loadTexture( index );

						} );
						break;

					case 'skin':
						dependency = this.loadSkin( index );
						break;

					case 'animation':
						dependency = this.loadAnimation( index );
						break;

					case 'camera':
						dependency = this.loadCamera( index );
						break;

					default:
						throw new Error( 'Unknown type: ' + type );

				}

				this.cache.add( cacheKey, dependency );

			}

			return dependency;

		}
		/**
   * Requests all dependencies of the specified type asynchronously, with caching.
   * @param {string} type
   * @return {Promise<Array<Object>>}
   */


		getDependencies( type ) {

			let dependencies = this.cache.get( type );

			if ( ! dependencies ) {

				const parser = this;
				const defs = this.json[ type + ( type === 'mesh' ? 'es' : 's' ) ] || [];
				dependencies = Promise.all( defs.map( function ( def, index ) {

					return parser.getDependency( type, index );

				} ) );
				this.cache.add( type, dependencies );

			}

			return dependencies;

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
   * @param {number} bufferIndex
   * @return {Promise<ArrayBuffer>}
   */


		loadBuffer( bufferIndex ) {

			const bufferDef = this.json.buffers[ bufferIndex ];
			const loader = this.fileLoader;

			if ( bufferDef.type && bufferDef.type !== 'arraybuffer' ) {

				throw new Error( 'THREE.GLTFLoader: ' + bufferDef.type + ' buffer type is not supported.' );

			} // If present, GLB container is required to be the first buffer.


			if ( bufferDef.uri === undefined && bufferIndex === 0 ) {

				return Promise.resolve( this.extensions[ EXTENSIONS.KHR_BINARY_GLTF ].body );

			}

			const options = this.options;
			return new Promise( function ( resolve, reject ) {

				loader.load( resolveURL( bufferDef.uri, options.path ), resolve, undefined, function () {

					reject( new Error( 'THREE.GLTFLoader: Failed to load buffer "' + bufferDef.uri + '".' ) );

				} );

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#buffers-and-buffer-views
   * @param {number} bufferViewIndex
   * @return {Promise<ArrayBuffer>}
   */


		loadBufferView( bufferViewIndex ) {

			const bufferViewDef = this.json.bufferViews[ bufferViewIndex ];
			return this.getDependency( 'buffer', bufferViewDef.buffer ).then( function ( buffer ) {

				const byteLength = bufferViewDef.byteLength || 0;
				const byteOffset = bufferViewDef.byteOffset || 0;
				return buffer.slice( byteOffset, byteOffset + byteLength );

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#accessors
   * @param {number} accessorIndex
   * @return {Promise<BufferAttribute|InterleavedBufferAttribute>}
   */


		loadAccessor( accessorIndex ) {

			const parser = this;
			const json = this.json;
			const accessorDef = this.json.accessors[ accessorIndex ];

			if ( accessorDef.bufferView === undefined && accessorDef.sparse === undefined ) {

				// Ignore empty accessors, which may be used to declare runtime
				// information about attributes coming from another source (e.g. Draco
				// compression extension).
				return Promise.resolve( null );

			}

			const pendingBufferViews = [];

			if ( accessorDef.bufferView !== undefined ) {

				pendingBufferViews.push( this.getDependency( 'bufferView', accessorDef.bufferView ) );

			} else {

				pendingBufferViews.push( null );

			}

			if ( accessorDef.sparse !== undefined ) {

				pendingBufferViews.push( this.getDependency( 'bufferView', accessorDef.sparse.indices.bufferView ) );
				pendingBufferViews.push( this.getDependency( 'bufferView', accessorDef.sparse.values.bufferView ) );

			}

			return Promise.all( pendingBufferViews ).then( function ( bufferViews ) {

				const bufferView = bufferViews[ 0 ];
				const itemSize = WEBGL_TYPE_SIZES[ accessorDef.type ];
				const TypedArray = WEBGL_COMPONENT_TYPES[ accessorDef.componentType ]; // For VEC3: itemSize is 3, elementBytes is 4, itemBytes is 12.

				const elementBytes = TypedArray.BYTES_PER_ELEMENT;
				const itemBytes = elementBytes * itemSize;
				const byteOffset = accessorDef.byteOffset || 0;
				const byteStride = accessorDef.bufferView !== undefined ? json.bufferViews[ accessorDef.bufferView ].byteStride : undefined;
				const normalized = accessorDef.normalized === true;
				let array, bufferAttribute; // The buffer is not interleaved if the stride is the item size in bytes.

				if ( byteStride && byteStride !== itemBytes ) {

					// Each "slice" of the buffer, as defined by 'count' elements of 'byteStride' bytes, gets its own THREE.InterleavedBuffer
					// This makes sure that IBA.count reflects accessor.count properly
					const ibSlice = Math.floor( byteOffset / byteStride );
					const ibCacheKey = 'InterleavedBuffer:' + accessorDef.bufferView + ':' + accessorDef.componentType + ':' + ibSlice + ':' + accessorDef.count;
					let ib = parser.cache.get( ibCacheKey );

					if ( ! ib ) {

						array = new TypedArray( bufferView, ibSlice * byteStride, accessorDef.count * byteStride / elementBytes ); // Integer parameters to IB/IBA are in array elements, not bytes.

						ib = new THREE.InterleavedBuffer( array, byteStride / elementBytes );
						parser.cache.add( ibCacheKey, ib );

					}

					bufferAttribute = new THREE.InterleavedBufferAttribute( ib, itemSize, byteOffset % byteStride / elementBytes, normalized );

				} else {

					if ( bufferView === null ) {

						array = new TypedArray( accessorDef.count * itemSize );

					} else {

						array = new TypedArray( bufferView, byteOffset, accessorDef.count * itemSize );

					}

					bufferAttribute = new THREE.BufferAttribute( array, itemSize, normalized );

				} // https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#sparse-accessors


				if ( accessorDef.sparse !== undefined ) {

					const itemSizeIndices = WEBGL_TYPE_SIZES.SCALAR;
					const TypedArrayIndices = WEBGL_COMPONENT_TYPES[ accessorDef.sparse.indices.componentType ];
					const byteOffsetIndices = accessorDef.sparse.indices.byteOffset || 0;
					const byteOffsetValues = accessorDef.sparse.values.byteOffset || 0;
					const sparseIndices = new TypedArrayIndices( bufferViews[ 1 ], byteOffsetIndices, accessorDef.sparse.count * itemSizeIndices );
					const sparseValues = new TypedArray( bufferViews[ 2 ], byteOffsetValues, accessorDef.sparse.count * itemSize );

					if ( bufferView !== null ) {

						// Avoid modifying the original ArrayBuffer, if the bufferView wasn't initialized with zeroes.
						bufferAttribute = new THREE.BufferAttribute( bufferAttribute.array.slice(), bufferAttribute.itemSize, bufferAttribute.normalized );

					}

					for ( let i = 0, il = sparseIndices.length; i < il; i ++ ) {

						const index = sparseIndices[ i ];
						bufferAttribute.setX( index, sparseValues[ i * itemSize ] );
						if ( itemSize >= 2 ) bufferAttribute.setY( index, sparseValues[ i * itemSize + 1 ] );
						if ( itemSize >= 3 ) bufferAttribute.setZ( index, sparseValues[ i * itemSize + 2 ] );
						if ( itemSize >= 4 ) bufferAttribute.setW( index, sparseValues[ i * itemSize + 3 ] );
						if ( itemSize >= 5 ) throw new Error( 'THREE.GLTFLoader: Unsupported itemSize in sparse THREE.BufferAttribute.' );

					}

				}

				return bufferAttribute;

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#textures
   * @param {number} textureIndex
   * @return {Promise<THREE.Texture>}
   */


		loadTexture( textureIndex ) {

			const json = this.json;
			const options = this.options;
			const textureDef = json.textures[ textureIndex ];
			const source = json.images[ textureDef.source ];
			let loader = this.textureLoader;

			if ( source.uri ) {

				const handler = options.manager.getHandler( source.uri );
				if ( handler !== null ) loader = handler;

			}

			return this.loadTextureImage( textureIndex, source, loader );

		}

		loadTextureImage( textureIndex, source, loader ) {

			const parser = this;
			const json = this.json;
			const options = this.options;
			const textureDef = json.textures[ textureIndex ];
			const URL = self.URL || self.webkitURL;
			let sourceURI = source.uri;
			let isObjectURL = false;
			let hasAlpha = true;
			if ( source.mimeType === 'image/jpeg' ) hasAlpha = false;

			if ( source.bufferView !== undefined ) {

				// Load binary image data from bufferView, if provided.
				sourceURI = parser.getDependency( 'bufferView', source.bufferView ).then( function ( bufferView ) {

					if ( source.mimeType === 'image/png' ) {

						// Inspect the PNG 'IHDR' chunk to determine whether the image could have an
						// alpha channel. This check is conservative — the image could have an alpha
						// channel with all values == 1, and the indexed type (colorType == 3) only
						// sometimes contains alpha.
						//
						// https://en.wikipedia.org/wiki/Portable_Network_Graphics#File_header
						const colorType = new DataView( bufferView, 25, 1 ).getUint8( 0, false );
						hasAlpha = colorType === 6 || colorType === 4 || colorType === 3;

					}

					isObjectURL = true;
					const blob = new Blob( [ bufferView ], {
						type: source.mimeType
					} );
					sourceURI = URL.createObjectURL( blob );
					return sourceURI;

				} );

			} else if ( source.uri === undefined ) {

				throw new Error( 'THREE.GLTFLoader: Image ' + textureIndex + ' is missing URI and bufferView' );

			}

			return Promise.resolve( sourceURI ).then( function ( sourceURI ) {

				return new Promise( function ( resolve, reject ) {

					let onLoad = resolve;

					if ( loader.isImageBitmapLoader === true ) {

						onLoad = function ( imageBitmap ) {

							resolve( new THREE.CanvasTexture( imageBitmap ) );

						};

					}

					loader.load( resolveURL( sourceURI, options.path ), onLoad, undefined, reject );

				} );

			} ).then( function ( texture ) {

				// Clean up resources and configure Texture.
				if ( isObjectURL === true ) {

					URL.revokeObjectURL( sourceURI );

				}

				texture.flipY = false;
				if ( textureDef.name ) texture.name = textureDef.name; // When there is definitely no alpha channel in the texture, set THREE.RGBFormat to save space.

				if ( ! hasAlpha ) texture.format = THREE.RGBFormat;
				const samplers = json.samplers || {};
				const sampler = samplers[ textureDef.sampler ] || {};
				texture.magFilter = WEBGL_FILTERS[ sampler.magFilter ] || THREE.LinearFilter;
				texture.minFilter = WEBGL_FILTERS[ sampler.minFilter ] || THREE.LinearMipmapLinearFilter;
				texture.wrapS = WEBGL_WRAPPINGS[ sampler.wrapS ] || THREE.RepeatWrapping;
				texture.wrapT = WEBGL_WRAPPINGS[ sampler.wrapT ] || THREE.RepeatWrapping;
				parser.associations.set( texture, {
					type: 'textures',
					index: textureIndex
				} );
				return texture;

			} );

		}
		/**
   * Asynchronously assigns a texture to the given material parameters.
   * @param {Object} materialParams
   * @param {string} mapName
   * @param {Object} mapDef
   * @return {Promise}
   */


		assignTexture( materialParams, mapName, mapDef ) {

			const parser = this;
			return this.getDependency( 'texture', mapDef.index ).then( function ( texture ) {

				// Materials sample aoMap from UV set 1 and other maps from UV set 0 - this can't be configured
				// However, we will copy UV set 0 to UV set 1 on demand for aoMap
				if ( mapDef.texCoord !== undefined && mapDef.texCoord != 0 && ! ( mapName === 'aoMap' && mapDef.texCoord == 1 ) ) {

					console.warn( 'THREE.GLTFLoader: Custom UV set ' + mapDef.texCoord + ' for texture ' + mapName + ' not yet supported.' );

				}

				if ( parser.extensions[ EXTENSIONS.KHR_TEXTURE_TRANSFORM ] ) {

					const transform = mapDef.extensions !== undefined ? mapDef.extensions[ EXTENSIONS.KHR_TEXTURE_TRANSFORM ] : undefined;

					if ( transform ) {

						const gltfReference = parser.associations.get( texture );
						texture = parser.extensions[ EXTENSIONS.KHR_TEXTURE_TRANSFORM ].extendTexture( texture, transform );
						parser.associations.set( texture, gltfReference );

					}

				}

				materialParams[ mapName ] = texture;

			} );

		}
		/**
   * Assigns final material to a THREE.Mesh, THREE.Line, or THREE.Points instance. The instance
   * already has a material (generated from the glTF material options alone)
   * but reuse of the same glTF material may require multiple threejs materials
   * to accommodate different primitive types, defines, etc. New materials will
   * be created if necessary, and reused from a cache.
   * @param  {Object3D} mesh THREE.Mesh, THREE.Line, or THREE.Points instance.
   */


		assignFinalMaterial( mesh ) {

			const geometry = mesh.geometry;
			let material = mesh.material;
			const useVertexTangents = geometry.attributes.tangent !== undefined;
			const useVertexColors = geometry.attributes.color !== undefined;
			const useFlatShading = geometry.attributes.normal === undefined;
			const useSkinning = mesh.isSkinnedMesh === true;
			const useMorphTargets = Object.keys( geometry.morphAttributes ).length > 0;
			const useMorphNormals = useMorphTargets && geometry.morphAttributes.normal !== undefined;

			if ( mesh.isPoints ) {

				const cacheKey = 'PointsMaterial:' + material.uuid;
				let pointsMaterial = this.cache.get( cacheKey );

				if ( ! pointsMaterial ) {

					pointsMaterial = new THREE.PointsMaterial();
					THREE.Material.prototype.copy.call( pointsMaterial, material );
					pointsMaterial.color.copy( material.color );
					pointsMaterial.map = material.map;
					pointsMaterial.sizeAttenuation = false; // glTF spec says points should be 1px

					this.cache.add( cacheKey, pointsMaterial );

				}

				material = pointsMaterial;

			} else if ( mesh.isLine ) {

				const cacheKey = 'LineBasicMaterial:' + material.uuid;
				let lineMaterial = this.cache.get( cacheKey );

				if ( ! lineMaterial ) {

					lineMaterial = new THREE.LineBasicMaterial();
					THREE.Material.prototype.copy.call( lineMaterial, material );
					lineMaterial.color.copy( material.color );
					this.cache.add( cacheKey, lineMaterial );

				}

				material = lineMaterial;

			} // Clone the material if it will be modified


			if ( useVertexTangents || useVertexColors || useFlatShading || useSkinning || useMorphTargets ) {

				let cacheKey = 'ClonedMaterial:' + material.uuid + ':';
				if ( material.isGLTFSpecularGlossinessMaterial ) cacheKey += 'specular-glossiness:';
				if ( useSkinning ) cacheKey += 'skinning:';
				if ( useVertexTangents ) cacheKey += 'vertex-tangents:';
				if ( useVertexColors ) cacheKey += 'vertex-colors:';
				if ( useFlatShading ) cacheKey += 'flat-shading:';
				if ( useMorphTargets ) cacheKey += 'morph-targets:';
				if ( useMorphNormals ) cacheKey += 'morph-normals:';
				let cachedMaterial = this.cache.get( cacheKey );

				if ( ! cachedMaterial ) {

					cachedMaterial = material.clone();
					if ( useSkinning ) cachedMaterial.skinning = true;
					if ( useVertexColors ) cachedMaterial.vertexColors = true;
					if ( useFlatShading ) cachedMaterial.flatShading = true;
					if ( useMorphTargets ) cachedMaterial.morphTargets = true;
					if ( useMorphNormals ) cachedMaterial.morphNormals = true;

					if ( useVertexTangents ) {

						cachedMaterial.vertexTangents = true; // https://github.com/mrdoob/three.js/issues/11438#issuecomment-507003995

						if ( cachedMaterial.normalScale ) cachedMaterial.normalScale.y *= - 1;
						if ( cachedMaterial.clearcoatNormalScale ) cachedMaterial.clearcoatNormalScale.y *= - 1;

					}

					this.cache.add( cacheKey, cachedMaterial );
					this.associations.set( cachedMaterial, this.associations.get( material ) );

				}

				material = cachedMaterial;

			} // workarounds for mesh and geometry


			if ( material.aoMap && geometry.attributes.uv2 === undefined && geometry.attributes.uv !== undefined ) {

				geometry.setAttribute( 'uv2', geometry.attributes.uv );

			}

			mesh.material = material;

		}

		getMaterialType( ) {

			return THREE.MeshStandardMaterial;

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#materials
   * @param {number} materialIndex
   * @return {Promise<Material>}
   */


		loadMaterial( materialIndex ) {

			const parser = this;
			const json = this.json;
			const extensions = this.extensions;
			const materialDef = json.materials[ materialIndex ];
			let materialType;
			const materialParams = {};
			const materialExtensions = materialDef.extensions || {};
			const pending = [];

			if ( materialExtensions[ EXTENSIONS.KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS ] ) {

				const sgExtension = extensions[ EXTENSIONS.KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS ];
				materialType = sgExtension.getMaterialType();
				pending.push( sgExtension.extendParams( materialParams, materialDef, parser ) );

			} else if ( materialExtensions[ EXTENSIONS.KHR_MATERIALS_UNLIT ] ) {

				const kmuExtension = extensions[ EXTENSIONS.KHR_MATERIALS_UNLIT ];
				materialType = kmuExtension.getMaterialType();
				pending.push( kmuExtension.extendParams( materialParams, materialDef, parser ) );

			} else {

				// Specification:
				// https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#metallic-roughness-material
				const metallicRoughness = materialDef.pbrMetallicRoughness || {};
				materialParams.color = new THREE.Color( 1.0, 1.0, 1.0 );
				materialParams.opacity = 1.0;

				if ( Array.isArray( metallicRoughness.baseColorFactor ) ) {

					const array = metallicRoughness.baseColorFactor;
					materialParams.color.fromArray( array );
					materialParams.opacity = array[ 3 ];

				}

				if ( metallicRoughness.baseColorTexture !== undefined ) {

					pending.push( parser.assignTexture( materialParams, 'map', metallicRoughness.baseColorTexture ) );

				}

				materialParams.metalness = metallicRoughness.metallicFactor !== undefined ? metallicRoughness.metallicFactor : 1.0;
				materialParams.roughness = metallicRoughness.roughnessFactor !== undefined ? metallicRoughness.roughnessFactor : 1.0;

				if ( metallicRoughness.metallicRoughnessTexture !== undefined ) {

					pending.push( parser.assignTexture( materialParams, 'metalnessMap', metallicRoughness.metallicRoughnessTexture ) );
					pending.push( parser.assignTexture( materialParams, 'roughnessMap', metallicRoughness.metallicRoughnessTexture ) );

				}

				materialType = this._invokeOne( function ( ext ) {

					return ext.getMaterialType && ext.getMaterialType( materialIndex );

				} );
				pending.push( Promise.all( this._invokeAll( function ( ext ) {

					return ext.extendMaterialParams && ext.extendMaterialParams( materialIndex, materialParams );

				} ) ) );

			}

			if ( materialDef.doubleSided === true ) {

				materialParams.side = THREE.DoubleSide;

			}

			const alphaMode = materialDef.alphaMode || ALPHA_MODES.OPAQUE;

			if ( alphaMode === ALPHA_MODES.BLEND ) {

				materialParams.transparent = true; // See: https://github.com/mrdoob/three.js/issues/17706

				materialParams.depthWrite = false;

			} else {

				materialParams.transparent = false;

				if ( alphaMode === ALPHA_MODES.MASK ) {

					materialParams.alphaTest = materialDef.alphaCutoff !== undefined ? materialDef.alphaCutoff : 0.5;

				}

			}

			if ( materialDef.normalTexture !== undefined && materialType !== THREE.MeshBasicMaterial ) {

				pending.push( parser.assignTexture( materialParams, 'normalMap', materialDef.normalTexture ) ); // https://github.com/mrdoob/three.js/issues/11438#issuecomment-507003995

				materialParams.normalScale = new THREE.Vector2( 1, - 1 );

				if ( materialDef.normalTexture.scale !== undefined ) {

					materialParams.normalScale.set( materialDef.normalTexture.scale, - materialDef.normalTexture.scale );

				}

			}

			if ( materialDef.occlusionTexture !== undefined && materialType !== THREE.MeshBasicMaterial ) {

				pending.push( parser.assignTexture( materialParams, 'aoMap', materialDef.occlusionTexture ) );

				if ( materialDef.occlusionTexture.strength !== undefined ) {

					materialParams.aoMapIntensity = materialDef.occlusionTexture.strength;

				}

			}

			if ( materialDef.emissiveFactor !== undefined && materialType !== THREE.MeshBasicMaterial ) {

				materialParams.emissive = new THREE.Color().fromArray( materialDef.emissiveFactor );

			}

			if ( materialDef.emissiveTexture !== undefined && materialType !== THREE.MeshBasicMaterial ) {

				pending.push( parser.assignTexture( materialParams, 'emissiveMap', materialDef.emissiveTexture ) );

			}

			return Promise.all( pending ).then( function () {

				let material;

				if ( materialType === GLTFMeshStandardSGMaterial ) {

					material = extensions[ EXTENSIONS.KHR_MATERIALS_PBR_SPECULAR_GLOSSINESS ].createMaterial( materialParams );

				} else {

					material = new materialType( materialParams );

				}

				if ( materialDef.name ) material.name = materialDef.name; // baseColorTexture, emissiveTexture, and specularGlossinessTexture use sRGB encoding.

				if ( material.map ) material.map.encoding = THREE.sRGBEncoding;
				if ( material.emissiveMap ) material.emissiveMap.encoding = THREE.sRGBEncoding;
				assignExtrasToUserData( material, materialDef );
				parser.associations.set( material, {
					type: 'materials',
					index: materialIndex
				} );
				if ( materialDef.extensions ) addUnknownExtensionsToUserData( extensions, material, materialDef );
				return material;

			} );

		}
		/** When THREE.Object3D instances are targeted by animation, they need unique names. */


		createUniqueName( originalName ) {

			const sanitizedName = THREE.PropertyBinding.sanitizeNodeName( originalName || '' );
			let name = sanitizedName;

			for ( let i = 1; this.nodeNamesUsed[ name ]; ++ i ) {

				name = sanitizedName + '_' + i;

			}

			this.nodeNamesUsed[ name ] = true;
			return name;

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#geometry
   *
   * Creates BufferGeometries from primitives.
   *
   * @param {Array<GLTF.Primitive>} primitives
   * @return {Promise<Array<BufferGeometry>>}
   */


		loadGeometries( primitives ) {

			const parser = this;
			const extensions = this.extensions;
			const cache = this.primitiveCache;

			function createDracoPrimitive( primitive ) {

				return extensions[ EXTENSIONS.KHR_DRACO_MESH_COMPRESSION ].decodePrimitive( primitive, parser ).then( function ( geometry ) {

					return addPrimitiveAttributes( geometry, primitive, parser );

				} );

			}

			const pending = [];

			for ( let i = 0, il = primitives.length; i < il; i ++ ) {

				const primitive = primitives[ i ];
				const cacheKey = createPrimitiveKey( primitive ); // See if we've already created this geometry

				const cached = cache[ cacheKey ];

				if ( cached ) {

					// Use the cached geometry if it exists
					pending.push( cached.promise );

				} else {

					let geometryPromise;

					if ( primitive.extensions && primitive.extensions[ EXTENSIONS.KHR_DRACO_MESH_COMPRESSION ] ) {

						// Use DRACO geometry if available
						geometryPromise = createDracoPrimitive( primitive );

					} else {

						// Otherwise create a new geometry
						geometryPromise = addPrimitiveAttributes( new THREE.BufferGeometry(), primitive, parser );

					} // Cache this geometry


					cache[ cacheKey ] = {
						primitive: primitive,
						promise: geometryPromise
					};
					pending.push( geometryPromise );

				}

			}

			return Promise.all( pending );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md#meshes
   * @param {number} meshIndex
   * @return {Promise<Group|Mesh|SkinnedMesh>}
   */


		loadMesh( meshIndex ) {

			const parser = this;
			const json = this.json;
			const extensions = this.extensions;
			const meshDef = json.meshes[ meshIndex ];
			const primitives = meshDef.primitives;
			const pending = [];

			for ( let i = 0, il = primitives.length; i < il; i ++ ) {

				const material = primitives[ i ].material === undefined ? createDefaultMaterial( this.cache ) : this.getDependency( 'material', primitives[ i ].material );
				pending.push( material );

			}

			pending.push( parser.loadGeometries( primitives ) );
			return Promise.all( pending ).then( function ( results ) {

				const materials = results.slice( 0, results.length - 1 );
				const geometries = results[ results.length - 1 ];
				const meshes = [];

				for ( let i = 0, il = geometries.length; i < il; i ++ ) {

					const geometry = geometries[ i ];
					const primitive = primitives[ i ]; // 1. create THREE.Mesh

					let mesh;
					const material = materials[ i ];

					if ( primitive.mode === WEBGL_CONSTANTS.TRIANGLES || primitive.mode === WEBGL_CONSTANTS.TRIANGLE_STRIP || primitive.mode === WEBGL_CONSTANTS.TRIANGLE_FAN || primitive.mode === undefined ) {

						// .isSkinnedMesh isn't in glTF spec. See ._markDefs()
						mesh = meshDef.isSkinnedMesh === true ? new THREE.SkinnedMesh( geometry, material ) : new THREE.Mesh( geometry, material );

						if ( mesh.isSkinnedMesh === true && ! mesh.geometry.attributes.skinWeight.normalized ) {

							// we normalize floating point skin weight array to fix malformed assets (see #15319)
							// it's important to skip this for non-float32 data since normalizeSkinWeights assumes non-normalized inputs
							mesh.normalizeSkinWeights();

						}

						if ( primitive.mode === WEBGL_CONSTANTS.TRIANGLE_STRIP ) {

							mesh.geometry = toTrianglesDrawMode( mesh.geometry, THREE.TriangleStripDrawMode );

						} else if ( primitive.mode === WEBGL_CONSTANTS.TRIANGLE_FAN ) {

							mesh.geometry = toTrianglesDrawMode( mesh.geometry, THREE.TriangleFanDrawMode );

						}

					} else if ( primitive.mode === WEBGL_CONSTANTS.LINES ) {

						mesh = new THREE.LineSegments( geometry, material );

					} else if ( primitive.mode === WEBGL_CONSTANTS.LINE_STRIP ) {

						mesh = new THREE.Line( geometry, material );

					} else if ( primitive.mode === WEBGL_CONSTANTS.LINE_LOOP ) {

						mesh = new THREE.LineLoop( geometry, material );

					} else if ( primitive.mode === WEBGL_CONSTANTS.POINTS ) {

						mesh = new THREE.Points( geometry, material );

					} else {

						throw new Error( 'THREE.GLTFLoader: Primitive mode unsupported: ' + primitive.mode );

					}

					if ( Object.keys( mesh.geometry.morphAttributes ).length > 0 ) {

						updateMorphTargets( mesh, meshDef );

					}

					mesh.name = parser.createUniqueName( meshDef.name || 'mesh_' + meshIndex );
					assignExtrasToUserData( mesh, meshDef );
					if ( primitive.extensions ) addUnknownExtensionsToUserData( extensions, mesh, primitive );
					parser.assignFinalMaterial( mesh );
					meshes.push( mesh );

				}

				if ( meshes.length === 1 ) {

					return meshes[ 0 ];

				}

				const group = new THREE.Group();

				for ( let i = 0, il = meshes.length; i < il; i ++ ) {

					group.add( meshes[ i ] );

				}

				return group;

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#cameras
   * @param {number} cameraIndex
   * @return {Promise<THREE.Camera>}
   */


		loadCamera( cameraIndex ) {

			let camera;
			const cameraDef = this.json.cameras[ cameraIndex ];
			const params = cameraDef[ cameraDef.type ];

			if ( ! params ) {

				console.warn( 'THREE.GLTFLoader: Missing camera parameters.' );
				return;

			}

			if ( cameraDef.type === 'perspective' ) {

				camera = new THREE.PerspectiveCamera( THREE.MathUtils.radToDeg( params.yfov ), params.aspectRatio || 1, params.znear || 1, params.zfar || 2e6 );

			} else if ( cameraDef.type === 'orthographic' ) {

				camera = new THREE.OrthographicCamera( - params.xmag, params.xmag, params.ymag, - params.ymag, params.znear, params.zfar );

			}

			if ( cameraDef.name ) camera.name = this.createUniqueName( cameraDef.name );
			assignExtrasToUserData( camera, cameraDef );
			return Promise.resolve( camera );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#skins
   * @param {number} skinIndex
   * @return {Promise<Object>}
   */


		loadSkin( skinIndex ) {

			const skinDef = this.json.skins[ skinIndex ];
			const skinEntry = {
				joints: skinDef.joints
			};

			if ( skinDef.inverseBindMatrices === undefined ) {

				return Promise.resolve( skinEntry );

			}

			return this.getDependency( 'accessor', skinDef.inverseBindMatrices ).then( function ( accessor ) {

				skinEntry.inverseBindMatrices = accessor;
				return skinEntry;

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#animations
   * @param {number} animationIndex
   * @return {Promise<AnimationClip>}
   */


		loadAnimation( animationIndex ) {

			const json = this.json;
			const animationDef = json.animations[ animationIndex ];
			const pendingNodes = [];
			const pendingInputAccessors = [];
			const pendingOutputAccessors = [];
			const pendingSamplers = [];
			const pendingTargets = [];

			for ( let i = 0, il = animationDef.channels.length; i < il; i ++ ) {

				const channel = animationDef.channels[ i ];
				const sampler = animationDef.samplers[ channel.sampler ];
				const target = channel.target;
				const name = target.node !== undefined ? target.node : target.id; // NOTE: target.id is deprecated.

				const input = animationDef.parameters !== undefined ? animationDef.parameters[ sampler.input ] : sampler.input;
				const output = animationDef.parameters !== undefined ? animationDef.parameters[ sampler.output ] : sampler.output;
				pendingNodes.push( this.getDependency( 'node', name ) );
				pendingInputAccessors.push( this.getDependency( 'accessor', input ) );
				pendingOutputAccessors.push( this.getDependency( 'accessor', output ) );
				pendingSamplers.push( sampler );
				pendingTargets.push( target );

			}

			return Promise.all( [ Promise.all( pendingNodes ), Promise.all( pendingInputAccessors ), Promise.all( pendingOutputAccessors ), Promise.all( pendingSamplers ), Promise.all( pendingTargets ) ] ).then( function ( dependencies ) {

				const nodes = dependencies[ 0 ];
				const inputAccessors = dependencies[ 1 ];
				const outputAccessors = dependencies[ 2 ];
				const samplers = dependencies[ 3 ];
				const targets = dependencies[ 4 ];
				const tracks = [];

				for ( let i = 0, il = nodes.length; i < il; i ++ ) {

					const node = nodes[ i ];
					const inputAccessor = inputAccessors[ i ];
					const outputAccessor = outputAccessors[ i ];
					const sampler = samplers[ i ];
					const target = targets[ i ];
					if ( node === undefined ) continue;
					node.updateMatrix();
					node.matrixAutoUpdate = true;
					let TypedKeyframeTrack;

					switch ( PATH_PROPERTIES[ target.path ] ) {

						case PATH_PROPERTIES.weights:
							TypedKeyframeTrack = THREE.NumberKeyframeTrack;
							break;

						case PATH_PROPERTIES.rotation:
							TypedKeyframeTrack = THREE.QuaternionKeyframeTrack;
							break;

						case PATH_PROPERTIES.position:
						case PATH_PROPERTIES.scale:
						default:
							TypedKeyframeTrack = THREE.VectorKeyframeTrack;
							break;

					}

					const targetName = node.name ? node.name : node.uuid;
					const interpolation = sampler.interpolation !== undefined ? INTERPOLATION[ sampler.interpolation ] : THREE.InterpolateLinear;
					const targetNames = [];

					if ( PATH_PROPERTIES[ target.path ] === PATH_PROPERTIES.weights ) {

						// Node may be a THREE.Group (glTF mesh with several primitives) or a THREE.Mesh.
						node.traverse( function ( object ) {

							if ( object.isMesh === true && object.morphTargetInfluences ) {

								targetNames.push( object.name ? object.name : object.uuid );

							}

						} );

					} else {

						targetNames.push( targetName );

					}

					let outputArray = outputAccessor.array;

					if ( outputAccessor.normalized ) {

						const scale = getNormalizedComponentScale( outputArray.constructor );
						const scaled = new Float32Array( outputArray.length );

						for ( let j = 0, jl = outputArray.length; j < jl; j ++ ) {

							scaled[ j ] = outputArray[ j ] * scale;

						}

						outputArray = scaled;

					}

					for ( let j = 0, jl = targetNames.length; j < jl; j ++ ) {

						const track = new TypedKeyframeTrack( targetNames[ j ] + '.' + PATH_PROPERTIES[ target.path ], inputAccessor.array, outputArray, interpolation ); // Override interpolation with custom factory method.

						if ( sampler.interpolation === 'CUBICSPLINE' ) {

							track.createInterpolant = function InterpolantFactoryMethodGLTFCubicSpline( result ) {

								// A CUBICSPLINE keyframe in glTF has three output values for each input value,
								// representing inTangent, splineVertex, and outTangent. As a result, track.getValueSize()
								// must be divided by three to get the interpolant's sampleSize argument.
								return new GLTFCubicSplineInterpolant( this.times, this.values, this.getValueSize() / 3, result );

							}; // Mark as CUBICSPLINE. `track.getInterpolation()` doesn't support custom interpolants.


							track.createInterpolant.isInterpolantFactoryMethodGLTFCubicSpline = true;

						}

						tracks.push( track );

					}

				}

				const name = animationDef.name ? animationDef.name : 'animation_' + animationIndex;
				return new THREE.AnimationClip( name, undefined, tracks );

			} );

		}

		createNodeMesh( nodeIndex ) {

			const json = this.json;
			const parser = this;
			const nodeDef = json.nodes[ nodeIndex ];
			if ( nodeDef.mesh === undefined ) return null;
			return parser.getDependency( 'mesh', nodeDef.mesh ).then( function ( mesh ) {

				const node = parser._getNodeRef( parser.meshCache, nodeDef.mesh, mesh ); // if weights are provided on the node, override weights on the mesh.


				if ( nodeDef.weights !== undefined ) {

					node.traverse( function ( o ) {

						if ( ! o.isMesh ) return;

						for ( let i = 0, il = nodeDef.weights.length; i < il; i ++ ) {

							o.morphTargetInfluences[ i ] = nodeDef.weights[ i ];

						}

					} );

				}

				return node;

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#nodes-and-hierarchy
   * @param {number} nodeIndex
   * @return {Promise<Object3D>}
   */


		loadNode( nodeIndex ) {

			const json = this.json;
			const extensions = this.extensions;
			const parser = this;
			const nodeDef = json.nodes[ nodeIndex ]; // reserve node's name before its dependencies, so the root has the intended name.

			const nodeName = nodeDef.name ? parser.createUniqueName( nodeDef.name ) : '';
			return function () {

				const pending = [];

				const meshPromise = parser._invokeOne( function ( ext ) {

					return ext.createNodeMesh && ext.createNodeMesh( nodeIndex );

				} );

				if ( meshPromise ) {

					pending.push( meshPromise );

				}

				if ( nodeDef.camera !== undefined ) {

					pending.push( parser.getDependency( 'camera', nodeDef.camera ).then( function ( camera ) {

						return parser._getNodeRef( parser.cameraCache, nodeDef.camera, camera );

					} ) );

				}

				parser._invokeAll( function ( ext ) {

					return ext.createNodeAttachment && ext.createNodeAttachment( nodeIndex );

				} ).forEach( function ( promise ) {

					pending.push( promise );

				} );

				return Promise.all( pending );

			}().then( function ( objects ) {

				let node; // .isBone isn't in glTF spec. See ._markDefs

				if ( nodeDef.isBone === true ) {

					node = new THREE.Bone();

				} else if ( objects.length > 1 ) {

					node = new THREE.Group();

				} else if ( objects.length === 1 ) {

					node = objects[ 0 ];

				} else {

					node = new THREE.Object3D();

				}

				if ( node !== objects[ 0 ] ) {

					for ( let i = 0, il = objects.length; i < il; i ++ ) {

						node.add( objects[ i ] );

					}

				}

				if ( nodeDef.name ) {

					node.userData.name = nodeDef.name;
					node.name = nodeName;

				}

				assignExtrasToUserData( node, nodeDef );
				if ( nodeDef.extensions ) addUnknownExtensionsToUserData( extensions, node, nodeDef );

				if ( nodeDef.matrix !== undefined ) {

					const matrix = new THREE.Matrix4();
					matrix.fromArray( nodeDef.matrix );
					node.applyMatrix4( matrix );

				} else {

					if ( nodeDef.translation !== undefined ) {

						node.position.fromArray( nodeDef.translation );

					}

					if ( nodeDef.rotation !== undefined ) {

						node.quaternion.fromArray( nodeDef.rotation );

					}

					if ( nodeDef.scale !== undefined ) {

						node.scale.fromArray( nodeDef.scale );

					}

				}

				parser.associations.set( node, {
					type: 'nodes',
					index: nodeIndex
				} );
				return node;

			} );

		}
		/**
   * Specification: https://github.com/KhronosGroup/glTF/tree/master/specification/2.0#scenes
   * @param {number} sceneIndex
   * @return {Promise<Group>}
   */


		loadScene( sceneIndex ) {

			const json = this.json;
			const extensions = this.extensions;
			const sceneDef = this.json.scenes[ sceneIndex ];
			const parser = this; // THREE.Loader returns THREE.Group, not Scene.
			// See: https://github.com/mrdoob/three.js/issues/18342#issuecomment-578981172

			const scene = new THREE.Group();
			if ( sceneDef.name ) scene.name = parser.createUniqueName( sceneDef.name );
			assignExtrasToUserData( scene, sceneDef );
			if ( sceneDef.extensions ) addUnknownExtensionsToUserData( extensions, scene, sceneDef );
			const nodeIds = sceneDef.nodes || [];
			const pending = [];

			for ( let i = 0, il = nodeIds.length; i < il; i ++ ) {

				pending.push( buildNodeHierachy( nodeIds[ i ], scene, json, parser ) );

			}

			return Promise.all( pending ).then( function () {

				return scene;

			} );

		}

	}

	function buildNodeHierachy( nodeId, parentObject, json, parser ) {

		const nodeDef = json.nodes[ nodeId ];
		return parser.getDependency( 'node', nodeId ).then( function ( node ) {

			if ( nodeDef.skin === undefined ) return node; // build skeleton here as well

			let skinEntry;
			return parser.getDependency( 'skin', nodeDef.skin ).then( function ( skin ) {

				skinEntry = skin;
				const pendingJoints = [];

				for ( let i = 0, il = skinEntry.joints.length; i < il; i ++ ) {

					pendingJoints.push( parser.getDependency( 'node', skinEntry.joints[ i ] ) );

				}

				return Promise.all( pendingJoints );

			} ).then( function ( jointNodes ) {

				node.traverse( function ( mesh ) {

					if ( ! mesh.isMesh ) return;
					const bones = [];
					const boneInverses = [];

					for ( let j = 0, jl = jointNodes.length; j < jl; j ++ ) {

						const jointNode = jointNodes[ j ];

						if ( jointNode ) {

							bones.push( jointNode );
							const mat = new THREE.Matrix4();

							if ( skinEntry.inverseBindMatrices !== undefined ) {

								mat.fromArray( skinEntry.inverseBindMatrices.array, j * 16 );

							}

							boneInverses.push( mat );

						} else {

							console.warn( 'THREE.GLTFLoader: Joint "%s" could not be found.', skinEntry.joints[ j ] );

						}

					}

					mesh.bind( new THREE.Skeleton( bones, boneInverses ), mesh.matrixWorld );

				} );
				return node;

			} );

		} ).then( function ( node ) {

			// build node hierachy
			parentObject.add( node );
			const pending = [];

			if ( nodeDef.children ) {

				const children = nodeDef.children;

				for ( let i = 0, il = children.length; i < il; i ++ ) {

					const child = children[ i ];
					pending.push( buildNodeHierachy( child, node, json, parser ) );

				}

			}

			return Promise.all( pending );

		} );

	}
	/**
 * @param {BufferGeometry} geometry
 * @param {GLTF.Primitive} primitiveDef
 * @param {GLTFParser} parser
 */


	function computeBounds( geometry, primitiveDef, parser ) {

		const attributes = primitiveDef.attributes;
		const box = new THREE.Box3();

		if ( attributes.POSITION !== undefined ) {

			const accessor = parser.json.accessors[ attributes.POSITION ];
			const min = accessor.min;
			const max = accessor.max; // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.

			if ( min !== undefined && max !== undefined ) {

				box.set( new THREE.Vector3( min[ 0 ], min[ 1 ], min[ 2 ] ), new THREE.Vector3( max[ 0 ], max[ 1 ], max[ 2 ] ) );

				if ( accessor.normalized ) {

					const boxScale = getNormalizedComponentScale( WEBGL_COMPONENT_TYPES[ accessor.componentType ] );
					box.min.multiplyScalar( boxScale );
					box.max.multiplyScalar( boxScale );

				}

			} else {

				console.warn( 'THREE.GLTFLoader: Missing min/max properties for accessor POSITION.' );
				return;

			}

		} else {

			return;

		}

		const targets = primitiveDef.targets;

		if ( targets !== undefined ) {

			const maxDisplacement = new THREE.Vector3();
			const vector = new THREE.Vector3();

			for ( let i = 0, il = targets.length; i < il; i ++ ) {

				const target = targets[ i ];

				if ( target.POSITION !== undefined ) {

					const accessor = parser.json.accessors[ target.POSITION ];
					const min = accessor.min;
					const max = accessor.max; // glTF requires 'min' and 'max', but VRM (which extends glTF) currently ignores that requirement.

					if ( min !== undefined && max !== undefined ) {

						// we need to get max of absolute components because target weight is [-1,1]
						vector.setX( Math.max( Math.abs( min[ 0 ] ), Math.abs( max[ 0 ] ) ) );
						vector.setY( Math.max( Math.abs( min[ 1 ] ), Math.abs( max[ 1 ] ) ) );
						vector.setZ( Math.max( Math.abs( min[ 2 ] ), Math.abs( max[ 2 ] ) ) );

						if ( accessor.normalized ) {

							const boxScale = getNormalizedComponentScale( WEBGL_COMPONENT_TYPES[ accessor.componentType ] );
							vector.multiplyScalar( boxScale );

						} // Note: this assumes that the sum of all weights is at most 1. This isn't quite correct - it's more conservative
						// to assume that each target can have a max weight of 1. However, for some use cases - notably, when morph targets
						// are used to implement key-frame animations and as such only two are active at a time - this results in very large
						// boxes. So for now we make a box that's sometimes a touch too small but is hopefully mostly of reasonable size.


						maxDisplacement.max( vector );

					} else {

						console.warn( 'THREE.GLTFLoader: Missing min/max properties for accessor POSITION.' );

					}

				}

			} // As per comment above this box isn't conservative, but has a reasonable size for a very large number of morph targets.


			box.expandByVector( maxDisplacement );

		}

		geometry.boundingBox = box;
		const sphere = new THREE.Sphere();
		box.getCenter( sphere.center );
		sphere.radius = box.min.distanceTo( box.max ) / 2;
		geometry.boundingSphere = sphere;

	}
	/**
 * @param {BufferGeometry} geometry
 * @param {GLTF.Primitive} primitiveDef
 * @param {GLTFParser} parser
 * @return {Promise<BufferGeometry>}
 */


	function addPrimitiveAttributes( geometry, primitiveDef, parser ) {

		const attributes = primitiveDef.attributes;
		const pending = [];

		function assignAttributeAccessor( accessorIndex, attributeName ) {

			return parser.getDependency( 'accessor', accessorIndex ).then( function ( accessor ) {

				geometry.setAttribute( attributeName, accessor );

			} );

		}

		for ( const gltfAttributeName in attributes ) {

			const threeAttributeName = ATTRIBUTES[ gltfAttributeName ] || gltfAttributeName.toLowerCase(); // Skip attributes already provided by e.g. Draco extension.

			if ( threeAttributeName in geometry.attributes ) continue;
			pending.push( assignAttributeAccessor( attributes[ gltfAttributeName ], threeAttributeName ) );

		}

		if ( primitiveDef.indices !== undefined && ! geometry.index ) {

			const accessor = parser.getDependency( 'accessor', primitiveDef.indices ).then( function ( accessor ) {

				geometry.setIndex( accessor );

			} );
			pending.push( accessor );

		}

		assignExtrasToUserData( geometry, primitiveDef );
		computeBounds( geometry, primitiveDef, parser );
		return Promise.all( pending ).then( function () {

			return primitiveDef.targets !== undefined ? addMorphTargets( geometry, primitiveDef.targets, parser ) : geometry;

		} );

	}
	/**
 * @param {BufferGeometry} geometry
 * @param {Number} drawMode
 * @return {BufferGeometry}
 */


	function toTrianglesDrawMode( geometry, drawMode ) {

		let index = geometry.getIndex(); // generate index if not present

		if ( index === null ) {

			const indices = [];
			const position = geometry.getAttribute( 'position' );

			if ( position !== undefined ) {

				for ( let i = 0; i < position.count; i ++ ) {

					indices.push( i );

				}

				geometry.setIndex( indices );
				index = geometry.getIndex();

			} else {

				console.error( 'THREE.GLTFLoader.toTrianglesDrawMode(): Undefined position attribute. Processing not possible.' );
				return geometry;

			}

		} //


		const numberOfTriangles = index.count - 2;
		const newIndices = [];

		if ( drawMode === THREE.TriangleFanDrawMode ) {

			// gl.TRIANGLE_FAN
			for ( let i = 1; i <= numberOfTriangles; i ++ ) {

				newIndices.push( index.getX( 0 ) );
				newIndices.push( index.getX( i ) );
				newIndices.push( index.getX( i + 1 ) );

			}

		} else {

			// gl.TRIANGLE_STRIP
			for ( let i = 0; i < numberOfTriangles; i ++ ) {

				if ( i % 2 === 0 ) {

					newIndices.push( index.getX( i ) );
					newIndices.push( index.getX( i + 1 ) );
					newIndices.push( index.getX( i + 2 ) );

				} else {

					newIndices.push( index.getX( i + 2 ) );
					newIndices.push( index.getX( i + 1 ) );
					newIndices.push( index.getX( i ) );

				}

			}

		}

		if ( newIndices.length / 3 !== numberOfTriangles ) {

			console.error( 'THREE.GLTFLoader.toTrianglesDrawMode(): Unable to generate correct amount of triangles.' );

		} // build final geometry


		const newGeometry = geometry.clone();
		newGeometry.setIndex( newIndices );
		return newGeometry;

	}

	THREE.GLTFLoader = GLTFLoader;

} )();

( function () {

	class SkeletonUtils {

		static retarget( target, source, options = {} ) {

			const pos = new THREE.Vector3(),
				quat = new THREE.Quaternion(),
				scale = new THREE.Vector3(),
				bindBoneMatrix = new THREE.Matrix4(),
				relativeMatrix = new THREE.Matrix4(),
				globalMatrix = new THREE.Matrix4();
			options.preserveMatrix = options.preserveMatrix !== undefined ? options.preserveMatrix : true;
			options.preservePosition = options.preservePosition !== undefined ? options.preservePosition : true;
			options.preserveHipPosition = options.preserveHipPosition !== undefined ? options.preserveHipPosition : false;
			options.useTargetMatrix = options.useTargetMatrix !== undefined ? options.useTargetMatrix : false;
			options.hip = options.hip !== undefined ? options.hip : 'hip';
			options.names = options.names || {};
			const sourceBones = source.isObject3D ? source.skeleton.bones : this.getBones( source ),
				bones = target.isObject3D ? target.skeleton.bones : this.getBones( target );
			let bindBones, bone, name, boneTo, bonesPosition; // reset bones

			if ( target.isObject3D ) {

				target.skeleton.pose();

			} else {

				options.useTargetMatrix = true;
				options.preserveMatrix = false;

			}

			if ( options.preservePosition ) {

				bonesPosition = [];

				for ( let i = 0; i < bones.length; i ++ ) {

					bonesPosition.push( bones[ i ].position.clone() );

				}

			}

			if ( options.preserveMatrix ) {

				// reset matrix
				target.updateMatrixWorld();
				target.matrixWorld.identity(); // reset children matrix

				for ( let i = 0; i < target.children.length; ++ i ) {

					target.children[ i ].updateMatrixWorld( true );

				}

			}

			if ( options.offsets ) {

				bindBones = [];

				for ( let i = 0; i < bones.length; ++ i ) {

					bone = bones[ i ];
					name = options.names[ bone.name ] || bone.name;

					if ( options.offsets && options.offsets[ name ] ) {

						bone.matrix.multiply( options.offsets[ name ] );
						bone.matrix.decompose( bone.position, bone.quaternion, bone.scale );
						bone.updateMatrixWorld();

					}

					bindBones.push( bone.matrixWorld.clone() );

				}

			}

			for ( let i = 0; i < bones.length; ++ i ) {

				bone = bones[ i ];
				name = options.names[ bone.name ] || bone.name;
				boneTo = this.getBoneByName( name, sourceBones );
				globalMatrix.copy( bone.matrixWorld );

				if ( boneTo ) {

					boneTo.updateMatrixWorld();

					if ( options.useTargetMatrix ) {

						relativeMatrix.copy( boneTo.matrixWorld );

					} else {

						relativeMatrix.copy( target.matrixWorld ).invert();
						relativeMatrix.multiply( boneTo.matrixWorld );

					} // ignore scale to extract rotation


					scale.setFromMatrixScale( relativeMatrix );
					relativeMatrix.scale( scale.set( 1 / scale.x, 1 / scale.y, 1 / scale.z ) ); // apply to global matrix

					globalMatrix.makeRotationFromQuaternion( quat.setFromRotationMatrix( relativeMatrix ) );

					if ( target.isObject3D ) {

						const boneIndex = bones.indexOf( bone ),
							wBindMatrix = bindBones ? bindBones[ boneIndex ] : bindBoneMatrix.copy( target.skeleton.boneInverses[ boneIndex ] ).invert();
						globalMatrix.multiply( wBindMatrix );

					}

					globalMatrix.copyPosition( relativeMatrix );

				}

				if ( bone.parent && bone.parent.isBone ) {

					bone.matrix.copy( bone.parent.matrixWorld ).invert();
					bone.matrix.multiply( globalMatrix );

				} else {

					bone.matrix.copy( globalMatrix );

				}

				if ( options.preserveHipPosition && name === options.hip ) {

					bone.matrix.setPosition( pos.set( 0, bone.position.y, 0 ) );

				}

				bone.matrix.decompose( bone.position, bone.quaternion, bone.scale );
				bone.updateMatrixWorld();

			}

			if ( options.preservePosition ) {

				for ( let i = 0; i < bones.length; ++ i ) {

					bone = bones[ i ];
					name = options.names[ bone.name ] || bone.name;

					if ( name !== options.hip ) {

						bone.position.copy( bonesPosition[ i ] );

					}

				}

			}

			if ( options.preserveMatrix ) {

				// restore matrix
				target.updateMatrixWorld( true );

			}

		}

		static retargetClip( target, source, clip, options = {} ) {

			options.useFirstFramePosition = options.useFirstFramePosition !== undefined ? options.useFirstFramePosition : false;
			options.fps = options.fps !== undefined ? options.fps : 30;
			options.names = options.names || [];

			if ( ! source.isObject3D ) {

				source = this.getHelperFromSkeleton( source );

			}

			const numFrames = Math.round( clip.duration * ( options.fps / 1000 ) * 1000 ),
				delta = 1 / options.fps,
				convertedTracks = [],
				mixer = new THREE.AnimationMixer( source ),
				bones = this.getBones( target.skeleton ),
				boneDatas = [];
			let positionOffset, bone, boneTo, boneData, name;
			mixer.clipAction( clip ).play();
			mixer.update( 0 );
			source.updateMatrixWorld();

			for ( let i = 0; i < numFrames; ++ i ) {

				const time = i * delta;
				this.retarget( target, source, options );

				for ( let j = 0; j < bones.length; ++ j ) {

					name = options.names[ bones[ j ].name ] || bones[ j ].name;
					boneTo = this.getBoneByName( name, source.skeleton );

					if ( boneTo ) {

						bone = bones[ j ];
						boneData = boneDatas[ j ] = boneDatas[ j ] || {
							bone: bone
						};

						if ( options.hip === name ) {

							if ( ! boneData.pos ) {

								boneData.pos = {
									times: new Float32Array( numFrames ),
									values: new Float32Array( numFrames * 3 )
								};

							}

							if ( options.useFirstFramePosition ) {

								if ( i === 0 ) {

									positionOffset = bone.position.clone();

								}

								bone.position.sub( positionOffset );

							}

							boneData.pos.times[ i ] = time;
							bone.position.toArray( boneData.pos.values, i * 3 );

						}

						if ( ! boneData.quat ) {

							boneData.quat = {
								times: new Float32Array( numFrames ),
								values: new Float32Array( numFrames * 4 )
							};

						}

						boneData.quat.times[ i ] = time;
						bone.quaternion.toArray( boneData.quat.values, i * 4 );

					}

				}

				mixer.update( delta );
				source.updateMatrixWorld();

			}

			for ( let i = 0; i < boneDatas.length; ++ i ) {

				boneData = boneDatas[ i ];

				if ( boneData ) {

					if ( boneData.pos ) {

						convertedTracks.push( new THREE.VectorKeyframeTrack( '.bones[' + boneData.bone.name + '].position', boneData.pos.times, boneData.pos.values ) );

					}

					convertedTracks.push( new THREE.QuaternionKeyframeTrack( '.bones[' + boneData.bone.name + '].quaternion', boneData.quat.times, boneData.quat.values ) );

				}

			}

			mixer.uncacheAction( clip );
			return new THREE.AnimationClip( clip.name, - 1, convertedTracks );

		}

		static getHelperFromSkeleton( skeleton ) {

			const source = new THREE.SkeletonHelper( skeleton.bones[ 0 ] );
			source.skeleton = skeleton;
			return source;

		}

		static getSkeletonOffsets( target, source, options = {} ) {

			const targetParentPos = new THREE.Vector3(),
				targetPos = new THREE.Vector3(),
				sourceParentPos = new THREE.Vector3(),
				sourcePos = new THREE.Vector3(),
				targetDir = new THREE.Vector2(),
				sourceDir = new THREE.Vector2();
			options.hip = options.hip !== undefined ? options.hip : 'hip';
			options.names = options.names || {};

			if ( ! source.isObject3D ) {

				source = this.getHelperFromSkeleton( source );

			}

			const nameKeys = Object.keys( options.names ),
				nameValues = Object.values( options.names ),
				sourceBones = source.isObject3D ? source.skeleton.bones : this.getBones( source ),
				bones = target.isObject3D ? target.skeleton.bones : this.getBones( target ),
				offsets = [];
			let bone, boneTo, name, i;
			target.skeleton.pose();

			for ( i = 0; i < bones.length; ++ i ) {

				bone = bones[ i ];
				name = options.names[ bone.name ] || bone.name;
				boneTo = this.getBoneByName( name, sourceBones );

				if ( boneTo && name !== options.hip ) {

					const boneParent = this.getNearestBone( bone.parent, nameKeys ),
						boneToParent = this.getNearestBone( boneTo.parent, nameValues );
					boneParent.updateMatrixWorld();
					boneToParent.updateMatrixWorld();
					targetParentPos.setFromMatrixPosition( boneParent.matrixWorld );
					targetPos.setFromMatrixPosition( bone.matrixWorld );
					sourceParentPos.setFromMatrixPosition( boneToParent.matrixWorld );
					sourcePos.setFromMatrixPosition( boneTo.matrixWorld );
					targetDir.subVectors( new THREE.Vector2( targetPos.x, targetPos.y ), new THREE.Vector2( targetParentPos.x, targetParentPos.y ) ).normalize();
					sourceDir.subVectors( new THREE.Vector2( sourcePos.x, sourcePos.y ), new THREE.Vector2( sourceParentPos.x, sourceParentPos.y ) ).normalize();
					const laterialAngle = targetDir.angle() - sourceDir.angle();
					const offset = new THREE.Matrix4().makeRotationFromEuler( new THREE.Euler( 0, 0, laterialAngle ) );
					bone.matrix.multiply( offset );
					bone.matrix.decompose( bone.position, bone.quaternion, bone.scale );
					bone.updateMatrixWorld();
					offsets[ name ] = offset;

				}

			}

			return offsets;

		}

		static renameBones( skeleton, names ) {

			const bones = this.getBones( skeleton );

			for ( let i = 0; i < bones.length; ++ i ) {

				const bone = bones[ i ];

				if ( names[ bone.name ] ) {

					bone.name = names[ bone.name ];

				}

			}

			return this;

		}

		static getBones( skeleton ) {

			return Array.isArray( skeleton ) ? skeleton : skeleton.bones;

		}

		static getBoneByName( name, skeleton ) {

			for ( let i = 0, bones = this.getBones( skeleton ); i < bones.length; i ++ ) {

				if ( name === bones[ i ].name ) return bones[ i ];

			}

		}

		static getNearestBone( bone, names ) {

			while ( bone.isBone ) {

				if ( names.indexOf( bone.name ) !== - 1 ) {

					return bone;

				}

				bone = bone.parent;

			}

		}

		static findBoneTrackData( name, tracks ) {

			const regexp = /\[(.*)\]\.(.*)/,
				result = {
					name: name
				};

			for ( let i = 0; i < tracks.length; ++ i ) {

				// 1 is track name
				// 2 is track type
				const trackData = regexp.exec( tracks[ i ].name );

				if ( trackData && name === trackData[ 1 ] ) {

					result[ trackData[ 2 ] ] = i;

				}

			}

			return result;

		}

		static getEqualsBonesNames( skeleton, targetSkeleton ) {

			const sourceBones = this.getBones( skeleton ),
				targetBones = this.getBones( targetSkeleton ),
				bones = [];

			search: for ( let i = 0; i < sourceBones.length; i ++ ) {

				const boneName = sourceBones[ i ].name;

				for ( let j = 0; j < targetBones.length; j ++ ) {

					if ( boneName === targetBones[ j ].name ) {

						bones.push( boneName );
						continue search;

					}

				}

			}

			return bones;

		}

		static clone( source ) {

			const sourceLookup = new Map();
			const cloneLookup = new Map();
			const clone = source.clone();
			parallelTraverse( source, clone, function ( sourceNode, clonedNode ) {

				sourceLookup.set( clonedNode, sourceNode );
				cloneLookup.set( sourceNode, clonedNode );

			} );
			clone.traverse( function ( node ) {

				if ( ! node.isSkinnedMesh ) return;
				const clonedMesh = node;
				const sourceMesh = sourceLookup.get( node );
				const sourceBones = sourceMesh.skeleton.bones;
				clonedMesh.skeleton = sourceMesh.skeleton.clone();
				clonedMesh.bindMatrix.copy( sourceMesh.bindMatrix );
				clonedMesh.skeleton.bones = sourceBones.map( function ( bone ) {

					return cloneLookup.get( bone );

				} );
				clonedMesh.bind( clonedMesh.skeleton, clonedMesh.bindMatrix );

			} );
			return clone;

		}

	}

	function parallelTraverse( a, b, callback ) {

		callback( a, b );

		for ( let i = 0; i < a.children.length; i ++ ) {

			parallelTraverse( a.children[ i ], b.children[ i ], callback );

		}

	}

	THREE.SkeletonUtils = SkeletonUtils;

} )();

/* Platformer Hero v10 — a smooth, motion-captured, fully customisable 3D character for 2D platformers.
   The character renders to a transparent canvas, so a plain 2D canvas game draws it like a sprite:
       hero.draw(ctx, screenX, screenY, pixelsPerUnit)

   Drive it either way:
       hero.update(dt, input, world)   built-in controller
       hero.pose(dt, motion)           your own physics; you only say what the character is doing

   input:  { move:-1..1, run, jump, jumpHeld, climb:-1..1, crouch, grab, face, action }
   world:  { groundAt:x=>y, platforms:[{x0,x1,y}], ladders:[{x,y0,y1}], stairs:[{x0,x1,y0,y1,steps}],
             solids:[{x0,x1,y0,y1}], crates:[{x,y,w,h}], water:[{x0,x1,y0,y1}], minX, maxX }
           PlatformerHero.stepWorld(world, dt) once a frame lets crates fall.

   The controller does: walk, run, variable-height jump, slopes and stairs with planted feet (running takes stairs
   two at a time), one-way platforms, ladders, solid walls and ceilings, wall slide and wall jump, ledge grab and
   climb-up, crouch and crawl (stays down under low ceilings), pushing and pulling crates, swimming, and moves.

   Look:   hero.setLook({ skin, hair, hairColor, beard, eyeColor, top, sleeves, bottom, legs, shoes, build, ... })
           PlatformerHero.randomLook()
   Speed:  hero.play('punch', { speed: 1.5 }) throws it faster, { speed: 0.7 } slower. A strike played during another
           strike chains straight out of it, so a list of strikes played one after another is a flowing combo.
   Moves:  hero.play(name). PlatformerHero.moves lists them all.
           hands: jab punch hook elbow bodyBlow uppercut haymaker headbutt shove     legs: kick lowKick knee highKick spinKick
           in the air: dropKick flyingKnee somersault backflip     blade: slash sideSlash thrust
           defence: block duck backstep leanBack weave sidestep (hero.blocking / hero.ducking / hero.evading)
           hero.stance = 0..1 raises the guard; hero.mark('bruise'|'blood'|'dirt'|'cut', 'head'|'body') leaves marks     other: pickup searchLow searchMid searchHigh wave taunt
           Strikes chain: play() another strike late in the current one and it flows straight on (hero.combo counts them).
   Hold:   hero.hold('sword' | 'torch' | 'box' | yourObject3D | null, { hand, pose })
   Hits:   hero.hit({ dir, power, zone, knockdown, out, style })   recoil by zone and force, or a knockdown (hero.down); out stays down until revive()
           hero.freeze(sec) holds a move for a beat when a blow lands.
   Many:   every character shares one WebGL renderer. PlatformerHero.loadMany(THREE, src, n, opts) builds a crowd from one file.
   Touch:  PlatformerHero.stick({ side:'left' })  ->  stick.x, stick.y  (on-screen stick)
   Facing: 'left' | 'right' | 'front' (toward the player) | 'back' (away, used on ladders)
   Others: list the other characters in world.actors (or hero.actors). A strike, wave, talk, give or taunt then turns the
           character to the nearest one in range and turns that one back, so the two always face each other. Both stay
           turned for a moment (hero.engaged is who they are turned to); wave, talk and give are answered.
           hero.play(name, { target: other }) names the target; hero.engage(other, sec) and
           PlatformerHero.faceEachOther(a, b) do just the turn; hero.faceToward(x) looks at a spot.

   Needs three.js (pass THREE in) and a rigged Mixamo-style glTF with idle / walk / run clips.
   The model's own mesh is hidden and a figure is built on its skeleton (pass look:false to keep the mesh). */
(function (root) {
  'use strict';
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v), lerp = (a, b, t) => a + (b - a) * t;
  const sstep = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
  // keyframes joined by a smooth curve (Catmull-Rom): a move passes through its poses without stopping at each one
  const kf = (ts, vs, u) => { const n = ts.length; if (u <= ts[0]) return vs[0]; for (let i = 1; i < n; i++) if (u <= ts[i]) { const t = (u - ts[i - 1]) / (ts[i] - ts[i - 1]), p0 = vs[i > 1 ? i - 2 : 0], p1 = vs[i - 1], p2 = vs[i], p3 = vs[i < n - 1 ? i + 1 : i];
      return 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t); } return vs[n - 1]; };
  const jolt = u => sstep(0, .09, u) * Math.exp(-3.1 * Math.max(0, u - .09));   // a blow snaps the body away, then it bleeds off
  const wob = u => Math.sin(u * 13) * Math.exp(-3.4 * u);                         // and the wobble while it settles
  const AB = h => h.side ? ['Left', 'Right', -1] : ['Right', 'Left', 1], K4 = [0, .3, .55, 1], flip = h => { h.side = !h.side; };
  const guard = (h, B, g) => { h._R(B + 'Arm', -g * .5); h._R(B + 'ForeArm', -g * 1.85); };
  const FACE = { right: Math.PI / 2, left: -Math.PI / 2, front: 0, back: Math.PI };

  const DEFAULT_LOOK = {
    skin: '#c98e63',
    hair: 'short',            // bald | buzz | short | long | ponytail | bun | afro | mohawk
    hairColor: '#2c1c12',
    beard: 'none',            // none | stubble | mustache | full
    eyeColor: '#5a4632', eyeSize: 1, eyeSpacing: 1,
    brow: 1,                  // brow thickness 0.5..1.6
    browTilt: 0,              // -1 worried .. 1 stern
    mouth: 0.2,               // -1 frown .. 1 smile
    lipColor: '#9a5148',
    freckles: false, glasses: false,
    hat: 'none',              // none | cap | beanie
    hatColor: '#b0302c',
    top: '#2f6f9f', sleeves: 'short',     // long | short | none
    bottom: '#2c3140', legs: 'long',      // long | shorts
    shoes: '#3a2a20', belt: true,
    build: 0.5,               // 0 slim .. 1 heavy
    height: 1,                // overall scale
    headSize: 1.12
  };
  const pick = (a, r) => a[Math.floor(r() * a.length)];

  // ---------- moves: each is a pose layered on the idle clip, u goes 0..1 over dur seconds
  const hold = u => sstep(0, 0.22, u) * sstep(1, 0.78, u);
  const MOVES = {
    pickup: { dur: 1.1, pose(h, u) { const k = hold(u); h._crouch(k * 1.1); h._R('Spine', k * .45); h._R('Spine1', k * .4); h._R('Neck', -k * .25); h._R('RightArm', -k * 1.0); h._R('RightForeArm', -k * .35); h._R('LeftArm', -k * .3); h._reach('Right', .42, .1, k); } },
    searchLow: { dur: 1.9, pose(h, u) { const k = hold(u), s = Math.sin(u * 26) * k; h._crouch(k * 1.05); h._R('Spine', k * .4); h._R('Spine1', k * .35); h._R('Neck', -k * .2); h._R('LeftArm', -k * .95 - s * .28); h._R('RightArm', -k * .95 + s * .28); h._R('LeftForeArm', -k * .5 + s * .35); h._R('RightForeArm', -k * .5 - s * .35); h._reach('Left', .4 + s * .06, .24 + s * .07, k); h._reach('Right', .46 - s * .06, .24 - s * .07, k); } },
    searchMid: { dur: 1.7, pose(h, u) { const k = hold(u), s = Math.sin(u * 24) * k; h._R('Spine1', k * .22); h._R('LeftArm', -k * 1.15 - s * .25); h._R('RightArm', -k * 1.15 + s * .25); h._R('LeftForeArm', -k * .75 + s * .4); h._R('RightForeArm', -k * .75 - s * .4); h._R('Neck', k * .15); } },
    searchHigh: { dur: 1.7, pose(h, u) { const k = hold(u), s = Math.sin(u * 24) * k; h.rootY = k * .06; h._R('Spine1', -k * .1); h._R('Neck', -k * .4); h._R('LeftArm', -k * 2.65 - s * .2); h._R('RightArm', -k * 2.65 + s * .2); h._R('LeftForeArm', -k * .3 + s * .3); h._R('RightForeArm', -k * .3 - s * .3); h._R('LeftFoot', k * .35); h._R('RightFoot', k * .35); } },
    punch: { dur: .46, strike: true, chain: .52, lunge: .45, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u), K = [0, .2, .45, .62, 1];
        h._R(A + 'Arm', kf(K, [0, .45, -1.5, -1.42, 0], u)); h._R(A + 'ForeArm', kf(K, [0, -1.8, -.05, -.1, 0], u)); h._U('Spine1', sg * kf(K, [0, -.4, .5, .42, 0], u)); h._U('Spine', sg * kf(K, [0, -.2, .28, .22, 0], u)); h._R('Spine', kf(K, [0, -.05, .2, .16, 0], u)); guard(h, B, g); } },
    kick: { dur: .6, strike: true, leg: true, chain: .6, lunge: .25, start(h) { h.side = !h.side; }, pose(h, u) { const A = h.side ? 'Left' : 'Right', g = hold(u);
        h._R(A + 'UpLeg', kf([0, .3, .55, 1], [0, -.95, -1.75, 0], u)); h._R(A + 'Leg', kf([0, .3, .55, 1], [0, 1.7, .1, 0], u)); h._R('Spine', -g * .3); h._R('Spine1', -g * .1);
        h._R('LeftArm', -g * .5); h._R('LeftForeArm', -g * 1.7); h._R('RightArm', -g * .5); h._R('RightForeArm', -g * 1.7); } },
    somersault: { air: true, vy: .78, vx: 1.35, pose(h, u) { const k = sstep(0, .25, u) * sstep(1, .75, u); h.spinX = 6.2832 * sstep(0, .92, u); h._R('LeftUpLeg', -k * 1.9); h._R('RightUpLeg', -k * 1.9); h._R('LeftLeg', k * 2.2); h._R('RightLeg', k * 2.2); h._R('Spine', k * .4); h._R('Spine1', k * .35); h._R('Neck', k * .3); h._R('LeftArm', -k * 1.2); h._R('RightArm', -k * 1.2); h._R('LeftForeArm', -k * 1.4); h._R('RightForeArm', -k * 1.4); } },
    backflip: { air: true, vy: .98, vx: -.3, pose(h, u) { const k = sstep(.12, .4, u) * sstep(.95, .68, u), sw = sstep(0, .18, u) * sstep(.55, .3, u); h.spinX = -6.2832 * sstep(.05, .95, u); h._R('LeftUpLeg', -k * 1.75); h._R('RightUpLeg', -k * 1.75); h._R('LeftLeg', k * 2.05); h._R('RightLeg', k * 2.05); h._R('Spine1', -sw * .3 + k * .3); h._R('LeftArm', -sw * 2.6 - k * .9); h._R('RightArm', -sw * 2.6 - k * .9); h._R('LeftForeArm', -k * 1.2); h._R('RightForeArm', -k * 1.2); } },
    flinch: { dur: .42, react: true, pose(h, u) { const k = jolt(u), kl = jolt(Math.max(0, u - .05)), w = wob(u);
        h._R('Spine', -k * .38 - w * .08); h._R('Spine1', -k * .25); h._R('Neck', -kl * .65 + w * .15); h._R('Head', -kl * .36); h._R('LeftArm', -k * .75 - w * .2); h._R('RightArm', -k * .5 + w * .2); h._R('LeftForeArm', -k * .9); h._R('RightForeArm', -k * .7); } },
    slash: { dur: .54, strike: true, chain: .62, lunge: .5, pose(h, u) { const S = h.held ? h.held.hand : 'Right', sg = S === 'Left' ? -1 : 1, K = [0, .3, .52, .7, 1];
        h._R(S + 'Arm', kf(K, [0, -2.7, -.25, .3, 0], u)); h._R(S + 'ForeArm', kf(K, [0, -1.1, .3, .2, 0], u)); h._U('Spine1', sg * kf(K, [0, -.35, .45, .6, 0], u)); h._R('Spine', kf(K, [0, -.12, .3, .4, 0], u)); h._crouch(kf(K, [0, 0, .15, .25, 0], u)); } },
    flinchBody: { dur: .46, react: true, pose(h, u) { const k = jolt(u), kl = jolt(Math.max(0, u - .05)), w = wob(u);
        h._crouch(k * .36); h._R('Spine', k * .58 + w * .08); h._R('Spine1', k * .4); h._R('Neck', kl * .32 - w * .12); h._R('LeftArm', -k * .45); h._R('LeftForeArm', -k * 1.5); h._R('RightArm', -k * .35 + w * .15); h._R('RightForeArm', -k * 1.6); } },
    flinchLegs: { dur: .44, react: true, pose(h, u) { const k = jolt(u), w = wob(u); h._crouch(k * .58); h._R('Spine', k * .24 + w * .1); h._R('LeftArm', -k * .7 - w * .3); h._R('RightArm', k * .35 + w * .3); h._R('Neck', -jolt(Math.max(0, u - .05)) * .18); } },
    flinchBack: { dur: .48, react: true, slide: true, pose(h, u) { const k = jolt(u), kl = jolt(Math.max(0, u - .06)), w = wob(u);
        h._R('Spine', k * .46 - w * .1); h._R('Spine1', k * .24); h._R('Neck', -kl * .55 + w * .12); h._R('LeftArm', k * .7 + w * .2); h._R('RightArm', k * .85 - w * .2); h._R('LeftForeArm', -k * .3); } },
    stagger: { dur: .76, react: true, slide: true, pose(h, u) { const k = sstep(0, .1, u) * (1 - sstep(.45, 1, u)), kl = sstep(.04, .16, u) * (1 - sstep(.5, 1, u)), st = Math.sin(u * 10), body = h.action && h.action.zone === 'body';
        if (body) { h._R('Spine', k * (.52 + .08 * st)); h._R('Spine1', k * .32); h._R('Neck', kl * .25); h._crouch(k * .28); } else { h._R('Spine', -k * (.4 + .08 * st)); h._R('Spine1', -k * .22); h._R('Neck', -kl * .55); h._R('Head', -kl * .28); }
        h._R('LeftArm', -k * (.95 + .45 * st)); h._R('RightArm', -k * (.6 - .45 * st)); h._R('LeftForeArm', -k * .7); h._R('RightForeArm', -k * .9); } },
    uppercut: { dur: .52, strike: true, chain: .64, lunge: .35, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u), K = [0, .28, .52, .66, 1];
        h._crouch(kf(K, [0, .5, .05, 0, 0], u)); h._R(A + 'Arm', kf(K, [0, .55, -2.3, -2.4, 0], u)); h._R(A + 'ForeArm', kf(K, [0, -1.7, -1.5, -1.4, 0], u)); h._U('Spine1', sg * kf(K, [0, -.45, .5, .45, 0], u)); h._R('Spine', kf(K, [0, .3, -.22, -.2, 0], u));
        guard(h, B, g); h.rootY += kf(K, [0, 0, .12, .1, 0], u); } },
    highKick: { dur: .62, strike: true, leg: true, chain: .66, lunge: .2, start(h) { h.side = !h.side; }, pose(h, u) { const A = h.side ? 'Left' : 'Right', B = h.side ? 'Right' : 'Left', K = [0, .3, .52, 1], g = hold(u);
        h._R(A + 'UpLeg', kf(K, [0, -1.1, -2.25, 0], u)); h._R(A + 'Leg', kf(K, [0, 1.9, .05, 0], u)); h._R('Spine', -g * .5); h._R('Spine1', -g * .15); h._R(B + 'Leg', g * .2);
        h._R('LeftArm', -g * .5); h._R('LeftForeArm', -g * 1.7); h._R('RightArm', -g * .5); h._R('RightForeArm', -g * 1.7); } },
    // ---- hands
    jab: { dur: .3, strike: true, chain: .45, lunge: .25, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u);
        h._R(A + 'Arm', kf(K4, [0, .1, -1.45, 0], u)); h._R(A + 'ForeArm', kf(K4, [0, -1.6, -.05, 0], u)); h._U('Spine1', sg * kf(K4, [0, -.15, .28, 0], u)); guard(h, B, g); } },
    hook: { dur: .5, strike: true, chain: .58, lunge: .35, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u), K = [0, .28, .48, .66, 1], tw = kf(K, [0, -.6, .8, 1.02, 0], u);
        h._U('Spine', sg * tw); h._U('Spine1', sg * tw * .6); h._F(A + 'Arm', sg * kf(K, [0, .55, .25, .1, 0], u)); h._R(A + 'Arm', kf(K, [0, -.9, -1.4, -1.25, 0], u)); h._R(A + 'ForeArm', kf(K, [0, -1.5, -1.35, -1.5, 0], u)); h._R('Spine', g * .12); guard(h, B, g); } },
    elbow: { dur: .36, strike: true, chain: .5, lunge: .5, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u);
        h._R(A + 'Arm', kf(K4, [0, -.6, -1.55, 0], u)); h._R(A + 'ForeArm', kf(K4, [0, -2.3, -2.2, 0], u)); h._U('Spine1', sg * kf(K4, [0, -.4, .55, 0], u)); h._R('Spine', g * .25); guard(h, B, g); } },
    bodyBlow: { dur: .42, strike: true, chain: .52, lunge: .4, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u);
        h._crouch(g * .32); h._R(A + 'Arm', kf(K4, [0, .35, -.85, 0], u)); h._R(A + 'ForeArm', kf(K4, [0, -1.5, -.5, 0], u)); h._R('Spine', kf(K4, [0, .25, .42, 0], u)); h._U('Spine1', sg * kf(K4, [0, -.35, .45, 0], u)); guard(h, B, g); } },
    haymaker: { dur: .7, strike: true, chain: .72, lunge: .6, start: flip, pose(h, u) { const [A, B, sg] = AB(h), g = hold(u), K = [0, .28, .5, .68, 1], tw = kf(K, [0, -.8, .95, 1.12, 0], u);
        h._U('Spine', sg * tw); h._U('Spine1', sg * tw * .5); h._R('Spine', kf(K, [0, -.12, .35, .42, 0], u)); h._R(A + 'Arm', kf(K, [0, .9, -1.9, -1.0, 0], u)); h._R(A + 'ForeArm', kf(K, [0, -1.0, -.5, -1.1, 0], u)); h._crouch(kf(K, [0, .25, .1, .28, 0], u)); guard(h, B, g * .6); } },
    headbutt: { dur: .44, strike: true, chain: .6, lunge: .55, pose(h, u) { h._R('Spine', kf(K4, [0, -.4, .6, 0], u)); h._R('Spine1', kf(K4, [0, -.25, .4, 0], u)); h._R('Neck', kf(K4, [0, -.3, .5, 0], u)); h._R('LeftArm', kf(K4, [0, .5, .35, 0], u)); h._R('RightArm', kf(K4, [0, .55, .3, 0], u)); } },
    shove: { dur: .46, strike: true, chain: .6, lunge: .5, pose(h, u) { for (const S of ['Left', 'Right']) { h._R(S + 'Arm', kf(K4, [0, -.4, -1.45, 0], u)); h._R(S + 'ForeArm', kf(K4, [0, -1.9, -.1, 0], u)); } h._R('Spine', kf(K4, [0, -.1, .3, 0], u)); } },
    // ---- legs
    knee: { dur: .46, strike: true, leg: true, chain: .58, lunge: .45, start: flip, pose(h, u) { const [A] = AB(h);
        h._R(A + 'UpLeg', kf(K4, [0, -.5, -1.7, 0], u)); h._R(A + 'Leg', kf(K4, [0, 1.2, 2.1, 0], u)); for (const S of ['Left', 'Right']) { h._R(S + 'Arm', kf(K4, [0, -1.6, -.6, 0], u)); h._R(S + 'ForeArm', kf(K4, [0, -.6, -1.4, 0], u)); }
        h._R('Spine', kf(K4, [0, -.15, .3, 0], u)); h.rootY += kf(K4, [0, 0, .06, 0], u); } },
    lowKick: { dur: .5, strike: true, leg: true, chain: .6, lunge: .2, start: flip, pose(h, u) { const [A, B] = AB(h), g = hold(u);
        h._R(A + 'UpLeg', kf(K4, [0, -.35, -.85, 0], u)); h._R(A + 'Leg', kf(K4, [0, 1.0, .05, 0], u)); h._R(B + 'Leg', g * .3); h._R(B + 'UpLeg', -g * .15); h._R('Spine', -g * .2); guard(h, 'Left', g * .7); guard(h, 'Right', g * .7); } },
    spinKick: { dur: .74, strike: true, leg: true, chain: .9, hitAt: [.6, .9], lunge: .25, start: flip, yaw: u => 6.2832 * sstep(.08, .74, u), pose(h, u) { const [A, B] = AB(h), g = hold(u), K = [0, .4, .72, .86, 1];
        h._R(A + 'UpLeg', kf(K, [0, -.8, -1.9, -1.8, 0], u)); h._R(A + 'Leg', kf(K, [0, 1.6, .15, .1, 0], u)); h._R(B + 'Leg', g * .2); h._R('Spine', -g * .35); h._R('LeftArm', -g * .9); h._R('RightArm', -g * .6); h._R('LeftForeArm', -g * 1.2); h._R('RightForeArm', -g * 1.4); } },
    dropKick: { air: true, strike: true, chain: 2, hitAt: [.4, .9], vy: .5, vx: 1.7, pose(h, u) { const k = sstep(0, .25, u) * sstep(1, .82, u), ext = sstep(.3, .55, u);
        h.spinX = -1.1 * k; for (const S of ['Left', 'Right']) { h._aim(S + 'UpLeg', S + 'Leg', lerp(.75, .12, ext), k); h._aim(S + 'Leg', S + 'Foot', lerp(-1.0, .1, ext), k); h._R(S + 'Arm', k * .5); h._R(S + 'ForeArm', -k * .8); } h._R('Neck', k * .5); } },
    flyingKnee: { air: true, strike: true, chain: 2, vy: .52, vx: 1.4, pose(h, u) { const k = sstep(0, .25, u) * sstep(1, .8, u);
        h._R('RightUpLeg', -k * 1.75); h._R('RightLeg', k * 2.0); h._R('LeftUpLeg', k * .5); h._R('LeftLeg', k * .6); h._R('Spine', -k * .15); h._R('LeftArm', -k * 1.2); h._R('RightArm', -k * 1.6); h._R('LeftForeArm', -k * 1.3); h._R('RightForeArm', -k * 1.1); } },
    // ---- blade
    thrust: { dur: .42, strike: true, chain: .55, lunge: .7, pose(h, u) { const S = h.held ? h.held.hand : 'Right', sg = S === 'Left' ? -1 : 1;
        h._R(S + 'Arm', kf(K4, [0, .4, -1.2, 0], u)); h._R(S + 'ForeArm', kf(K4, [0, -1.4, .1, 0], u)); h._R(S + 'Hand', kf(K4, [0, 0, 1.25, 0], u)); h._R('Spine', kf(K4, [0, -.05, .32, 0], u)); h._U('Spine1', sg * kf(K4, [0, -.3, .4, 0], u)); h._crouch(hold(u) * .22); } },
    sideSlash: { dur: .54, strike: true, chain: .62, lunge: .45, pose(h, u) { const S = h.held ? h.held.hand : 'Right', sg = S === 'Left' ? -1 : 1, K = [0, .3, .52, .7, 1], tw = kf(K, [0, -.85, .9, 1.1, 0], u);
        h._U('Spine', sg * tw); h._U('Spine1', sg * tw * .5); h._R(S + 'Arm', kf(K, [0, -1.3, -1.3, -1.0, 0], u)); h._R(S + 'ForeArm', kf(K, [0, -.9, -.2, -.35, 0], u)); } },
    // ---- defence and attitude
    block: { dur: .55, guard: true, pose(h, u) { const g = hold(u); for (const S of ['Left', 'Right']) { h._R(S + 'Arm', -g * 1.15); h._R(S + 'ForeArm', -g * 2.1); } h._R('Spine', g * .15); h._crouch(g * .18); } },
    duck: { dur: .5, low: true, pose(h, u) { const g = hold(u); h._crouch(g * .9); h._R('Spine', g * .45); h._R('Neck', -g * .3); guard(h, 'Left', g * .8); guard(h, 'Right', g * .8); } },
    backstep: { air: true, vy: .24, vx: -1.15, pose(h, u) { const k = sstep(0, .3, u) * sstep(1, .7, u); h._R('Spine', -k * .12); h._R('LeftUpLeg', -k * .4); h._R('RightLeg', k * .4); guard(h, 'Left', k * .7); guard(h, 'Right', k * .7); } },
    leanBack: { dur: .44, evade: 'head', pose(h, u) { const g = hold(u); h._R('Spine', -g * .5); h._R('Spine1', -g * .3); h._R('Neck', -g * .15); h._R('LeftUpLeg', -g * .12); h._crouch(g * .2); h._R('LeftArm', -g * .35); h._R('RightArm', g * .25); } },
    weave: { dur: .5, low: true, evade: 'head', pose(h, u) { const g = hold(u), sg = h.side ? 1 : -1; h._crouch(g * .7); h._R('Spine', g * .5); h._U('Spine', sg * g * .45); h._R('Neck', -g * .35); guard(h, 'Left', g); guard(h, 'Right', g); } },
    sidestep: { dur: .36, pose(h, u) { const g = hold(u), b = Math.sin(Math.PI * u); h.rootY += b * .07; h._crouch(g * .22); h._R('Spine', -g * .1); guard(h, 'Left', g * .8); guard(h, 'Right', g * .8); } },
    taunt: { dur: 1.9, social: true, range: 5, start(h) { h.tv = ((h.tv === undefined ? Math.floor(Math.random() * 3) : h.tv + 1 + Math.floor(Math.random() * 2))) % 3; }, pose(h, u) { const g = hold(u), v = h.tv || 0;
        if (v === 0) { const b = Math.sin(u * 27);                                               // "come on": chest out, arms wide, both hands beckoning
          for (const [S, sg] of [['Left', 1], ['Right', -1]]) { h._R(S + 'Arm', -g * .85); h._F(S + 'Arm', sg * g * .6); h._R(S + 'ForeArm', -g * (1.0 + .75 * b)); }
          h._R('Spine', -g * .2); h._R('Spine1', -g * .12); h._R('Neck', g * (.1 + .12 * b)); h._crouch(g * (.22 + .1 * Math.abs(b))); h._F('Spine', g * .08 * Math.sin(u * 9)); }
        else if (v === 1) { const w = sstep(0, .22, u) * (1 - sstep(.22, .4, u)), r = sstep(.22, .42, u) * sstep(1, .8, u), sh = Math.sin(u * 46) * r;   // wind down, then rear back and roar with both arms flexed
          h._crouch(w * .7 + r * .12); h._R('Spine', w * .35 - r * .3); h._R('Spine1', -r * .2); h._R('Neck', w * .2 - r * .42); h._U('Spine1', sh * .07);
          for (const [S, sg] of [['Left', 1], ['Right', -1]]) { h._R(S + 'Arm', -w * .5); h._R(S + 'ForeArm', -w * 1.6); h._F(S + 'Arm', sg * r * (1.3 + .04 * sh)); h._F(S + 'ForeArm', sg * r * 1.55); h._R(S + 'Arm', -r * .25); } }
        else { const p = sstep(0, .16, u) * (1 - sstep(.3, .42, u)), c = sstep(.34, .48, u) * sstep(1, .82, u), b = Math.sin(u * 34);                    // point him out, then beat the chest and stamp
          h._R('RightArm', -p * 1.55); h._R('RightForeArm', -p * .1); h._R('Spine', p * .12 - c * .18); h._U('Spine1', -p * .25); h._R('Neck', -c * .2);
          h._R('LeftArm', -c * (.75 + .12 * b)); h._R('LeftForeArm', -c * (2.0 + .32 * b)); h._R('RightArm', -c * (.75 - .12 * b)); h._R('RightForeArm', -c * (2.0 - .32 * b)); h._F('LeftArm', c * .35); h._F('RightArm', -c * .35);
          h._crouch(c * (.18 + .14 * Math.abs(b))); h._U('Spine', c * .1 * b); } } },
    flinchTwist: { dur: .5, react: true, pose(h, u) { const k = jolt(u), kl = jolt(Math.max(0, u - .05)), w = wob(u), sg = h.side ? 1 : -1;
        h._U('Spine', sg * (k * .85 + w * .15)); h._U('Spine1', sg * k * .45); h._U('Neck', sg * kl * .65); h._R('Neck', -kl * .32); h._R('Spine', -k * .16); h._R('LeftArm', -k * .85 - w * .3); h._R('RightArm', -k * .4 + w * .3); h._R('LeftForeArm', -k * .6); h._crouch(k * .2); } },
    wave: { dur: 2.3, face: 'front', social: true, range: 5, answer: 'wave', pose(h, u) { const k = hold(u), w = Math.sin(u * 24), w2 = Math.sin(u * 24 + .7);   // a big wave: the whole arm sweeps overhead, the body sways with it
        h._R('RightArm', -k * (2.75 + .2 * w)); h._F('RightArm', -k * (.3 + .42 * w)); h._F('RightForeArm', -k * .5 * w2); h._R('RightForeArm', -k * (.25 + .2 * w2));
        h._F('LeftArm', k * .4); h._R('LeftArm', -k * .15); h._R('LeftForeArm', -k * .45);
        h._F('Spine', -k * .1 * w); h._F('Spine1', -k * .08 * w); h._R('Spine', -k * .1); h._F('Neck', k * .1 * w); h._R('Neck', -k * .12); h._crouch(k * .16 * (.5 - .5 * Math.cos(u * 48))); } },
    talk: { dur: 2.6, social: true, range: 3.5, answer: 'nod', pose(h, u) { const k = hold(u), a = Math.sin(u * 15), b = Math.sin(u * 11 + 1); h._R('RightArm', -k * (.5 + .15 * a)); h._R('RightForeArm', -k * (1.25 + .3 * b)); h._R('LeftArm', -k * .22); h._R('LeftForeArm', -k * (.8 + .25 * a)); h._R('Neck', k * .07 * Math.sin(u * 19)); h._U('Spine1', k * .07 * Math.sin(u * 6)); } },
    nod: { dur: 1.5, pose(h, u) { const k = hold(u); h._R('Neck', k * (.1 + .14 * Math.sin(u * 20))); h._R('Spine2', k * .04); } },
    give: { dur: 1.4, social: true, range: 2.2, answer: 'give', pose(h, u) { const k = hold(u); h._R('RightArm', -k * 1.3); h._R('RightForeArm', -k * .3); h._R('Spine', k * .12); h._R('Neck', -k * .08); } }
  };

  // ---------- level helpers
  const stairY = (st, x) => { const n = st.steps, tw = (st.x1 - st.x0) / n, r = (st.y1 - st.y0) / n; if (x <= st.x0) return st.y0; if (x >= st.x1) return st.y1; const k = Math.floor((x - st.x0) / tw); return st.y0 + r * (r > 0 ? k + 1 : k); };
  const terrainAt = (world, x) => { let f = world.groundAt ? world.groundAt(x) : -1e9; if (world.stairs) for (const s of world.stairs) if (x >= s.x0 && x <= s.x1) f = Math.max(f, stairY(s, x)); return f; };
  const waterAt = (world, x, y) => { if (world.water) for (const w of world.water) if (x >= w.x0 && x <= w.x1 && y < w.y1 && y > w.y0) return w; return null; };
  /** Slide a crate by dx, stopping at walls, other crates, steep ground and the world's edges. Returns how far it went. */
  function moveCrate(c, dx, W) {
    if (!dx) return 0; const w = W.world, dir = Math.sign(dx), h2 = c.w / 2; let nx = c.x + dx;
    if (w.minX !== undefined) nx = Math.max(w.minX + h2, nx); if (w.maxX !== undefined) nx = Math.min(w.maxX - h2, nx);
    if (W.terrain(nx + dir * h2) > c.y + 0.2) return 0;
    for (const s of W.solids) { if (s.crate === c || s.y1 <= c.y + 0.05 || s.y0 >= c.y + c.h - 0.05) continue;
      if (nx + h2 > s.x0 && nx - h2 < s.x1) nx = dir > 0 ? Math.min(nx, s.x0 - h2) : Math.max(nx, s.x1 + h2); }
    const moved = (nx - c.x) * dir > 0 ? nx - c.x : 0; c.x += moved; return moved;
  }
  // ---------- things to hold, built in the rig's bone units (centimetres)
  const ITEMS = {
    sword: { pose: 'low', make(T) { const g = new T.Group(), m = c => new T.MeshPhongMaterial({ color: c, shininess: 60, specular: 0x666666 });
        const blade = new T.Mesh(new T.BoxGeometry(3.6, 64, 2.4), m('#dfe4ea')); blade.position.y = 40; const guard = new T.Mesh(new T.BoxGeometry(14, 2.4, 2.8), m('#b88f3a')); guard.position.y = 7.5;
        const grip = new T.Mesh(new T.CylinderGeometry(1.6, 1.6, 14, 8), m('#4a3020')); g.add(blade, guard, grip); g.rotation.set.apply(g.rotation, PlatformerHero.itemRot); const h = new T.Group(); h.add(g); h.position.set(0, 9, 3); h.userData.tip = [g, 72]; return h; } },
    torch: { pose: 'low', make(T) { const g = new T.Group();
        const stick = new T.Mesh(new T.CylinderGeometry(1.5, 1.2, 36, 8), new T.MeshLambertMaterial({ color: '#5a3c22' })); stick.position.y = 10;
        const f1 = new T.Mesh(new T.SphereGeometry(5.5, 12, 10), new T.MeshBasicMaterial({ color: '#ff9a2a' })); f1.position.y = 31; f1.scale.y = 1.4;
        const f2 = new T.Mesh(new T.SphereGeometry(3, 10, 8), new T.MeshBasicMaterial({ color: '#ffe27a' })); f2.position.y = 30; f2.scale.y = 1.5;
        g.add(stick, f1, f2); g.rotation.set.apply(g.rotation, PlatformerHero.itemRot); const h = new T.Group(); h.add(g); h.position.set(0, 9, 3); return h; } },
    box: { pose: 'both', bone: 'Spine2', make(T) { const b = new T.Mesh(new T.BoxGeometry(40, 30, 30), new T.MeshLambertMaterial({ color: '#b0803e' })); b.position.set(0, -6, 32); return b; } }
  };

  class PlatformerHero {
    constructor(THREE, gltf, opts) {
      const o = this.o = Object.assign({
        size: 320,             // sprite canvas size in CSS pixels (square)
        view: 3.4,             // world units the sprite canvas covers top to bottom
        walkSpeed: 4.2, runSpeed: 7.6, accel: 14, airAccel: 5,
        gravity: 30, jumpSpeed: 11.5, climbSpeed: 2.4,
        stepUp: 0.35, turnRate: 10,
        halfWidth: 0.3, height: 1.75, crouchHeight: 0.95,   // body box for walls and ceilings
        jumpCut: 0.45,         // letting go of jump early cuts the rise to this fraction of jumpSpeed
        wallSlide: true, wallSlideSpeed: 2.6, wallJump: true,
        ledgeGrab: true, hangDrop: 1.78, climbUpTime: 0.8,   // hangDrop = how far the feet hang below the ledge
        crawlFactor: 0.42, pushFactor: 0.5,                 // speed while crawling / pushing or pulling a crate
        swimSpeed: 2.8, swimDepth: 1.3, swimChest: 1.05,    // floats with the feet swimDepth below the surface
        downTime: 0.9, getUpTime: 0.8, lieDrop: -0.9,      // knockdown
        blendTime: 0.18, smooth: 26, follow: 0.5,   // follow = how much momentum limbs carry through a move (0 = none)
          // smooth = how tightly the upper body follows a move (lower = looser)
              // seconds to flow from one move into the next
        stairStride: true, stairRunSpeed: 5.0,              // above this speed stairs are taken two at a time
        shared: true,          // share one renderer between all characters
        uphillSlow: 0.3,       // how much a 45 degree climb slows the character (0 = not at all)
        footIK: true,          // plant feet on slopes and stair treads
        modelYaw: Math.PI,     // Mixamo models face -Z
        clips: { idle: 'Idle', walk: 'Walk', run: 'Run', rest: 'TPose' },   // rest: the rig's T-pose clip, used to build a relaxed standing pose (leave out to stand in the idle clip)
        walkClipSpeed: 1.7, runClipSpeed: 5.2, blendRate: 10,
        look: {}               // see DEFAULT_LOOK; false keeps the model's own mesh
      }, opts || {});
      const T = this.T = THREE;
      // one WebGL renderer and canvas for every character (shared:false gives this one its own)
      const mk = () => { const c = document.createElement('canvas'), r = new T.WebGLRenderer({ canvas: c, alpha: true, antialias: true }); r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2)); r.setClearColor(0x000000, 0); return { canvas: c, renderer: r, size: 0, shared: o.shared }; };
      const sh = this._sh = o.shared ? (PlatformerHero._shared || (PlatformerHero._shared = mk())) : mk();
      this.canvas = sh.canvas; this.renderer = sh.renderer; this._dirty = true;
      this.scene = new T.Scene(); this.scene.add(new T.HemisphereLight(0xffffff, 0x8c8078, 0.74));
      const key = new T.DirectionalLight(0xfff1dc, 0.68); key.position.set(2.5, 4, 5); this.scene.add(key);
      const fill = new T.DirectionalLight(0x9db8ff, 0.3); fill.position.set(-4, 1.5, 2.5); this.scene.add(fill);
      const v = o.view; this.camera = new T.OrthographicCamera(-v / 2, v / 2, v * 0.92, -v * 0.08, 0.1, 50); this.camera.position.set(0, 0, 12);
      // holder turns to face; spin flips the body about its centre; model is the rig
      this.holder = new T.Group(); this.spin = new T.Group(); this.spin.position.y = 1; this.model = gltf.scene; this.model.rotation.y = o.modelYaw; this.model.position.y = -1;
      this.spin.add(this.model); this.holder.add(this.spin); this.scene.add(this.holder);
      this.own = []; this.bones = {};
      this.model.traverse(m => { if (m.isMesh) { m.frustumCulled = false; this.own.push(m); } if (m.isBone) this.bones[m.name.replace(/^mixamorig:?/, '')] = m; });
      this.mixer = new T.AnimationMixer(this.model);
      const find = n => gltf.animations.find(a => a.name.toLowerCase() === n.toLowerCase()) || gltf.animations.find(a => a.name.toLowerCase().includes(n.toLowerCase()));
      this.act = {};
      for (const k of ['idle', 'walk', 'run']) { const c = find(o.clips[k]); if (!c) throw new Error('PlatformerHero: no "' + o.clips[k] + '" clip'); this.act[k] = this.mixer.clipAction(c); this.act[k].play(); this.act[k].setEffectiveWeight(k === 'idle' ? 1 : 0); }
      this.w = { idle: 1, walk: 0, run: 0 };
      this._pendRest = o.clips.rest && find(o.clips.rest);
      this._q1 = new T.Quaternion(); this._q2 = new T.Quaternion(); this._q3 = new T.Quaternion(); this._ax = new T.Vector3(); this._v = new T.Vector3();
      this.x = 0; this.y = 0; this.vx = 0; this.vy = 0; this.speed = 0;
      this.facing = 'right'; this.heading = FACE.right; this.grounded = true; this.airTime = 0;
      this.climbing = false; this.ladder = null; this.phase = 0; this.cw = 0; this.dropT = 0; this.crouchW = 0; this.stepOff = 0;
      this.airW = 0; this.airT = 0; this.fallV = 0; this.landK = 0; this.ikW = 0; this.pelv = 0; this.lean = 0; this.footG = [0, 0]; this.footA = [0, 0];
      this._iv = [0, 1, 2, 3, 4, 5].map(() => new T.Vector3()); this._iq = [0, 1, 2, 3].map(() => new T.Quaternion()); this._zAx = new T.Vector3(0, 0, 1);
      this.action = null; this.side = false; this.rootY = 0; this.spinX = 0; this.parts = []; this.look = null;
      this.touch = 0; this.pushing = 0; this.grabbing = null; this.wallSlide = 0; this.wallT = 0; this.wallDir = 0; this.lockT = 0; this.grabT = 0; this.jumping = false; this.crouched = false;
      this.hang = null; this.swimming = false; this.swimOutT = 0; this.swimP = 0; this.ko = null; this.held = null; this.crawlP = 0; this.stairRun = false;
      this.reachT = { Left: null, Right: null }; this.crouchDrop = 0; this.crawlK = 0; this.pushTop = 1;
      this.holdW = 0; this.crawlW = 0; this.pushW = 0; this.wallW = 0; this.hangW = 0; this.swimW = 0; this.stairW = 0;
      this.restOK = false; this.lifeT = Math.random() * 9; this.lifeW = 0; this.actors = []; this.focus = null;
      if (this._pendRest) this._buildRest(this._pendRest);
      if (o.look !== false) this.setLook(o.look);
      this._measure();
      this.blist = Object.values(this.bones); this.lastQ = this.blist.map(b => b.quaternion.clone()); this.snapQ = this.blist.map(b => b.quaternion.clone()); this.blendW = 0;
      this.yaw = 0; this.smoothT = 0; this.legB = this.blist.map(b => /UpLeg|Leg|Foot|Toe|Hips/.test(b.name));
      this.prevQ = this.blist.map(b => b.quaternion.clone()); this.stance = 0; this.stanceW = 0; this._st = 0;
      this.plantW = 0; this.pl = { wx: [null, null], st: [null, null], spread: 0 };
      this.combo = 0; this.queued = null; this.queueT = 0; this.flashT = 0; this._flash = 0; this.mats = this.mats || [];
    }
    // Replace the idle clip with a relaxed, symmetric standing pose built from the rig's T-pose.
    _buildRest(tp) {
      const T = this.T, a = this.mixer.clipAction(tp), h = this.heading; for (const k in this.act) this.act[k].setEffectiveWeight(0);
      a.play(); a.setEffectiveWeight(1); this.mixer.update(0); this.heading = 0; this.yaw = 0; this.holder.rotation.y = 0; this.holder.updateMatrixWorld(true);
      this._F('LeftArm', -1.42); this._F('RightArm', 1.42); this._R('LeftArm', -.06); this._R('RightArm', -.06); this._R('LeftForeArm', -.22); this._R('RightForeArm', -.22);
      this._U('LeftUpLeg', .1); this._U('RightUpLeg', -.1);
      const tr = []; for (const n in this.bones) { const b = this.bones[n], q = b.quaternion.toArray(), q2 = q.slice(); q2[0] += 2e-4;   // the tiny wobble makes the mixer rewrite every bone each frame, so pose layers never pile up
        tr.push(new T.QuaternionKeyframeTrack(b.name + '.quaternion', [0, .5, 1], q.concat(q2, q))); }
      const hp = this.bones.Hips; if (hp) { const p = hp.position.toArray(); tr.push(new T.VectorKeyframeTrack(hp.name + '.position', [0, 1], p.concat(p))); }
      a.stop(); this.act.idle.stop(); this.act.idle = this.mixer.clipAction(new T.AnimationClip('Rest', 1, tr)); this.act.idle.play(); this.act.idle.setEffectiveWeight(1); this.heading = h; this.restOK = true;
    }
    static load(THREE, src, opts) {
      return new Promise((res, rej) => { const L = new THREE.GLTFLoader(), ok = g => { try { res(new PlatformerHero(THREE, g, opts)); } catch (e) { rej(e); } };
        if (typeof src === 'string') L.load(src, ok, undefined, rej); else L.parse(src, '', ok, rej); });
    }
    static get moves() { return Object.keys(MOVES); }
    static get defaultLook() { return Object.assign({}, DEFAULT_LOOK); }
    /** A random believable person. Pass your own rng() for repeatable results. */
    static randomLook(r) {
      r = r || Math.random; const clothes = ['#2f6f9f', '#a8322e', '#3d7a45', '#d8b23a', '#6a4a8a', '#e8e4da', '#2a2c34', '#c2703a', '#3a8a8a', '#7a8a96'];
      const hc = pick(['#17100c', '#2c1c12', '#4a2e1a', '#6e4a26', '#a8743a', '#d6b46a', '#8a2e1a', '#9a9a98', '#e4e2dc'], r);
      return { skin: pick(['#f3d3bd', '#e8bd9a', '#d9a577', '#c98e63', '#a8703f', '#8a5630', '#6a3e22', '#4a2a18'], r), hair: pick(['bald', 'buzz', 'short', 'short', 'long', 'ponytail', 'bun', 'afro', 'mohawk'], r), hairColor: hc,
        beard: pick(['none', 'none', 'none', 'stubble', 'mustache', 'full'], r), eyeColor: pick(['#4a3626', '#5a4632', '#3a5a7a', '#4a7a5a', '#6a6a72'], r), eyeSize: .85 + r() * .35, eyeSpacing: .92 + r() * .16,
        brow: .7 + r() * .8, browTilt: r() * 1.2 - .5, mouth: r() * 1.2 - .3, lipColor: pick(['#9a5148', '#b0605a', '#7a4038', '#c2706a'], r), freckles: r() < .2, glasses: r() < .2,
        hat: pick(['none', 'none', 'none', 'cap', 'beanie'], r), hatColor: pick(clothes, r), top: pick(clothes, r), sleeves: pick(['long', 'short', 'short', 'none'], r), bottom: pick(['#2c3140', '#3a3026', '#4a5a6a', '#1e2228', '#6a5a44', '#34506a'], r), legs: pick(['long', 'long', 'shorts'], r),
        shoes: pick(['#3a2a20', '#1c1c20', '#e4e2dc', '#7a3a2a'], r), belt: r() < .6, build: r(), height: .92 + r() * .16, headSize: .96 + r() * .1,
        jaw: r(), chin: r(), cheek: r(), browRidge: r(), noseSize: .8 + r() * .8, noseWidth: .78 + r() * .65, noseLength: .88 + r() * .28, noseBridge: r() < .25 ? r() : 0, earSize: .85 + r() * .45, lips: .7 + r() * .7, mouthWidth: .88 + r() * .26, eyeTilt: (r() - .4) * .22, faceWidth: .93 + r() * .14, faceLength: .95 + r() * .12, age: r(), tired: r() * .6 };
    }

    // ================= look =================
    /** A square of cloth that has been lived in: base colour, weave, fading, grime, stains, a patch or two, and tears with what is underneath showing. wear 0 (new) to 1 (rags). */
    static clothTexture(T, color, seed, wear, under) { const c = document.createElement('canvas'), S = 256; c.width = c.height = S; const g = c.getContext('2d'); let sd = (seed | 0) || 1; const R = () => ((sd = (sd * 1664525 + 1013904223) >>> 0) / 4294967296), w = clamp(wear, 0, 1);
      const blot = (x, y, rx, ry, col) => { for (const ox of [-S, 0, S]) { const gr = g.createRadialGradient(x + ox, y, 0, x + ox, y, rx); gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.save(); g.translate(x + ox, y); g.scale(1, ry / rx); g.translate(-x - ox, -y); g.fillStyle = gr; g.fillRect(x + ox - rx, y - rx, rx * 2, rx * 2); g.restore(); } };
      g.fillStyle = color; g.fillRect(0, 0, S, S);
      for (let i = 0; i < 26; i++) blot(R() * S, R() * S, 20 + R() * 46, 14 + R() * 40, R() < .5 ? `rgba(255,250,235,${(.03 + .07 * w).toFixed(3)})` : `rgba(0,0,0,${(.04 + .08 * w).toFixed(3)})`);                       // sun and washing have not faded it evenly
      g.globalAlpha = .025 + .02 * w; g.fillStyle = '#000'; for (let y = 0; y < S; y += 3) g.fillRect(0, y, S, 1); g.fillStyle = '#fff'; for (let x = 0; x < S; x += 3) g.fillRect(x, 0, 1, S); g.globalAlpha = 1;                 // the weave
      for (let i = 0; i < 8 + 22 * w; i++) blot(R() * S, R() * S, 6 + R() * 26, 5 + R() * 20, `rgba(${46 + (R() * 20 | 0)},${36 + (R() * 14 | 0)},${24 + (R() * 10 | 0)},${(.08 + .22 * w * R()).toFixed(3)})`);                      // grime
      for (let i = 0; i < 2 + 5 * w; i++) { const x = R() * S, y = R() * S, r = 12 + R() * 24, kind = R(), col = kind < .25 ? '70,14,10' : kind < .6 ? '24,20,16' : '58,44,22'; g.fillStyle = `rgba(${col},${(.2 + .3 * w).toFixed(3)})`;      // stains: old blood, oil, mud
        for (const ox of [-S, 0, S]) { g.beginPath(); for (let k = 0; k <= 14; k++) { const a = k / 14 * 6.2832, rr = r * (.6 + .5 * Math.abs(Math.sin(a * 3 + x) * Math.cos(a * 2 + y)) + R() * .15); k ? g.lineTo(x + ox + Math.cos(a) * rr, y + Math.sin(a) * rr * .8) : g.moveTo(x + ox + Math.cos(a) * rr, y + Math.sin(a) * rr * .8); } g.closePath(); g.fill(); } blot(x, y, r * 1.5, r * 1.2, `rgba(${col},${(.12 + .16 * w).toFixed(3)})`); }
      for (let i = 0; i < Math.round(w * 1.3 * R() + w * .4); i++) { const x = 20 + R() * (S - 70), y = 20 + R() * (S - 70), pw = 22 + R() * 26, ph = 18 + R() * 24, rot = (R() - .5) * .5; g.save(); g.translate(x + pw / 2, y + ph / 2); g.rotate(rot);              // a patch, stitched on by hand
        g.fillStyle = ['#5a5248', '#6a5a44', '#4a505a', '#6a4a40', '#55604a'][R() * 5 | 0]; g.fillRect(-pw / 2, -ph / 2, pw, ph); g.fillStyle = 'rgba(0,0,0,.14)'; g.fillRect(-pw / 2, -ph / 2, pw, ph * .5); g.strokeStyle = 'rgba(225,215,190,.75)'; g.lineWidth = 1.2; g.setLineDash([3, 3]); g.strokeRect(-pw / 2 + 2, -ph / 2 + 2, pw - 4, ph - 4); g.setLineDash([]); g.restore(); }
      for (let i = 0; i < Math.round(w * 4.5 * R() + w * 2); i++) { const x = 16 + R() * (S - 32), y = 16 + R() * (S - 32), ln = 12 + R() * 34 * w, ang = R() * 3.14, wd = 4 + R() * 10 * w; g.save(); g.translate(x, y); g.rotate(ang);                         // a tear: ragged, dark at the edge, with what is under it showing through
        g.beginPath(); g.moveTo(-ln, 0); for (let k = 1; k <= 8; k++) g.lineTo(-ln + ln * 2 * k / 8, -wd * Math.sin(k / 8 * Math.PI) * (.6 + R() * .7)); for (let k = 7; k >= 0; k--) g.lineTo(-ln + ln * 2 * k / 8, wd * Math.sin(k / 8 * Math.PI) * (.6 + R() * .7)); g.closePath(); g.fillStyle = under || '#1a1614'; g.fill(); g.fillStyle = 'rgba(0,0,0,.16)'; g.fill(); g.strokeStyle = 'rgba(12,10,8,.85)'; g.lineWidth = 1.4; g.stroke();
        g.strokeStyle = 'rgba(230,222,200,.5)'; g.lineWidth = .7; for (let k = 0; k < 9; k++) { const tx = -ln + R() * ln * 2, sg = R() < .5 ? -1 : 1; g.beginPath(); g.moveTo(tx, sg * wd * .6); g.lineTo(tx + (R() - .5) * 5, sg * (wd + 2 + R() * 5)); g.stroke(); } g.restore(); }
      for (const y0 of [0, S]) for (let x = 0; x < S; x += 5) { const d = (2 + R() * 9) * (.3 + w); g.fillStyle = 'rgba(14,11,9,.6)'; g.beginPath(); g.moveTo(x, y0); g.lineTo(x + 2.5, y0 + (y0 ? -d : d)); g.lineTo(x + 5, y0); g.fill(); }                    // hems gone to threads
      const t = new T.CanvasTexture(c); t.wrapS = T.RepeatWrapping; t.wrapT = T.ClampToEdgeWrapping; t.anisotropy = 4; return t; }
    setLook(look) {
      const T = this.T, L = this.look = Object.assign({}, DEFAULT_LOOK, this.look || {}, look || {});
      for (const p of this.parts) { if (p.parent) p.parent.remove(p); p.traverse(q => { if (q.geometry && q.geometry !== this._sph) q.geometry.dispose(); if (q.material) { if (q.material.map) q.material.map.dispose(); q.material.dispose(); } }); }
      this.parts = []; for (const m of this.own) m.visible = false;
      const SPH = this._sph || (this._sph = new T.SphereGeometry(1, 20, 14)), mat = c => new T.MeshPhongMaterial({ color: c, shininess: 16, specular: 0x1e1e1e });
      const M = { skin: mat(L.skin), top: mat(L.top), bottom: mat(L.bottom), shoes: mat(L.shoes), hair: mat(L.hairColor), hat: mat(L.hatColor), belt: mat('#2a2018'), dark: mat('#1a1a1e') };
      if (L.wear > 0) { const sd0 = (L.wearSeed | 0) || 7, tx = (col, k, wr, un) => { const m = new T.MeshPhongMaterial({ color: 0xffffff, map: PlatformerHero.clothTexture(T, col, sd0 * 31 + k * 977, wr, un), shininess: 5, specular: 0x0c0c0c }); return m; };
        M.top = tx(L.top, 1, L.wearTop == null ? L.wear : L.wearTop, L.under || L.skin); M.bottom = tx(L.bottom, 2, Math.min(1, L.wear * 1.1), L.skin); M.shoes = tx(L.shoes, 3, L.wear * .6, '#14110f'); M.hat = tx(L.hatColor, 4, L.wear * .5, '#14110f'); M.L = { top: tx(L.top, 5, L.wearTop == null ? L.wear : L.wearTop, L.under || L.skin), bottom: tx(L.bottom, 6, Math.min(1, L.wear * 1.1), L.skin), shoes: tx(L.shoes, 7, L.wear * .6, '#14110f') };
        { const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d'); let sd = sd0 * 131; const R = () => ((sd = (sd * 1664525 + 1013904223) >>> 0) / 4294967296); g.fillStyle = L.skin; g.fillRect(0, 0, 128, 128); for (let i = 0; i < 22 * L.wear + 4; i++) { const x = R() * 128, y = R() * 128, r = 6 + R() * 20, gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, `rgba(48,36,26,${(.12 + .3 * L.wear * R()).toFixed(3)})`); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2); } const t = new T.CanvasTexture(c); t.wrapS = t.wrapT = T.RepeatWrapping; M.skin = new T.MeshPhongMaterial({ color: 0xffffff, map: t, shininess: 12, specular: 0x1a1512 }); } }   this._M = M; // and the skin of the hands and arms has not seen soap either
      const b = clamp(L.build, 0, 1), fat = lerp(.86, 1.24, b), limb = lerp(.88, 1.16, b), B = this.bones;
      const add = (bn, mesh) => { if (!B[bn]) return mesh; B[bn].add(mesh); this.parts.push(mesh); mesh.traverse(q => { q.frustumCulled = false; }); return mesh; };
      const ell = (m, rx, ry, rz, x, y, z) => { const g = new T.Mesh(SPH, m); g.scale.set(rx, ry, rz); g.position.set(x || 0, y || 0, z || 0); return g; };
      const capsule = (m, child, r0, r1) => { const d = child.position, len = d.length(), pts = []; for (let i = 0; i <= 5; i++) { const a = -1.5708 + i * .31416; pts.push(new T.Vector2(Math.max(.001, r0 * Math.cos(a)), r0 * Math.sin(a))); } for (let i = 0; i <= 5; i++) { const a = i * .31416; pts.push(new T.Vector2(Math.max(.001, r1 * Math.cos(a)), len + r1 * Math.sin(a))); }
        const g = new T.Mesh(new T.LatheGeometry(pts, 14), m); g.quaternion.setFromUnitVectors(new T.Vector3(0, 1, 0), d.clone().normalize()); return g; };
      // torso: one smooth skinned surface from hips to neck, so the body bends without seams
      const bw = lerp(.94, 1.1, b), belly = lerp(.95, 1.4, b), srcM = this.own.find(m => m.isSkinnedMesh);
      this.torso = [16.4 * bw, 13, 11.3 * fat, 0, 5, 0];
      if (!(srcM && B.Hips && B.Spine && B.Spine1 && B.Spine2 && B.Neck && B.Head && B.LeftArm && B.RightArm && B.LeftForeArm && this._torso(srcM, L, M, fat, bw, belly, limb))) {
        add('Hips', ell(M.bottom, 15.2 * fat, 11.5, 10.6 * fat, 0, 1, 0)); if (L.belt) add('Hips', ell(M.belt, 15.6 * fat, 2.2, 11 * fat, 0, 8.5, 0));
        add('Spine', ell(M.top, 14.6 * fat * lerp(1, 1.12, b), 17, 10 * fat * lerp(1, 1.2, b), 0, 5, .5));
        add('Spine1', ell(M.top, 15.6 * fat, 17, 10.4 * fat, 0, 6, 0)); add('Spine2', ell(M.top, 17 * bw, 13, 10.8 * fat, 0, 5, 0)); add('Neck', ell(M.skin, 4.9 * limb, 7, 4.9 * limb, 0, 1, 0)); }
      // limbs: turned profiles with the swell of muscle, round at the joints; cloth sits a little proud of the skin
      const part = (m, child, ts, vs, t0, t1, grow) => { const d = child.position, len = d.length(), r = t => kf(ts, vs, t) * limb + (grow || 0), pts = [], r0 = r(t0), r1 = r(t1);
        if (t0 <= 0) for (let i = 0; i < 6; i++) { const a = -1.5708 + i * .2618; pts.push(new T.Vector2(Math.max(.001, r0 * Math.cos(a)), r0 * Math.sin(a))); }
        for (let i = 0; i <= 14; i++) { const t = lerp(t0, t1, i / 14); pts.push(new T.Vector2(r(t), t * len)); }
        if (t1 >= 1) for (let i = 1; i <= 6; i++) { const a = i * .2618; pts.push(new T.Vector2(Math.max(.001, r1 * Math.cos(a)), len + r1 * Math.sin(a))); } else pts.push(new T.Vector2(r1 - 1.1, t1 * len - .2));
        const g = new T.Mesh(new T.LatheGeometry(pts, 18), m); g.quaternion.setFromUnitVectors(new T.Vector3(0, 1, 0), d.clone().normalize()); return g; };
      const AT = [0, .3, .7, 1], AV = [5.3, 5.5, 4.5, 4.1], FT = [0, .22, .7, 1], FV = [4.1, 4.5, 3.3, 2.9], TT = [0, .25, .7, 1], TV = [9.5, 9.6, 7.3, 6.2], ST = [0, .25, .62, 1], SV = [5.9, 6.3, 4.6, 3.8];
      const slv = L.sleeves, shorts = L.legs === 'shorts';
      for (const S of ['Left', 'Right']) {
        const Ms = S === 'Left' && M.L ? M.L : M;
        add(S + 'Arm', ell(slv === 'none' ? M.skin : Ms.top, 5.3 * limb + (slv === 'none' ? 0 : .8), 5.3 * limb + (slv === 'none' ? 0 : .8), 5.3 * limb + (slv === 'none' ? 0 : .8)));
        if (B[S + 'ForeArm']) { if (slv === 'long') add(S + 'Arm', part(Ms.top, B[S + 'ForeArm'], AT, AV, 0, 1, .7)); else { add(S + 'Arm', part(M.skin, B[S + 'ForeArm'], AT, AV, 0, 1)); if (slv === 'short') add(S + 'Arm', part(Ms.top, B[S + 'ForeArm'], AT, AV, 0, .56, .9)); } }
        if (B[S + 'Hand']) { add(S + 'ForeArm', part(M.skin, B[S + 'Hand'], FT, FV, 0, 1)); if (slv === 'long') add(S + 'ForeArm', part(Ms.top, B[S + 'Hand'], FT, [4.9, 5.1, 4.4, 4.0], 0, .93, 0)); }
        const sx = S === 'Left' ? -1 : 1, fin = ell(M.skin, 3.5, 4.3, 1.55, 0, 10.6, .7); fin.rotation.x = .3;                                 // palm, fingers curled a little, thumb
        add(S + 'Hand', ell(M.skin, 3.9, 4.8, 1.9, 0, 4.6, 0)); add(S + 'Hand', fin); const th = ell(M.skin, 1.35, 3.3, 1.4, sx * 3.7, 4.6, 1.3); th.rotation.z = sx * .45; add(S + 'Hand', th);
        if (B[S + 'Leg']) { if (shorts) { add(S + 'UpLeg', part(M.skin, B[S + 'Leg'], TT, TV, 0, 1)); add(S + 'UpLeg', part(Ms.bottom, B[S + 'Leg'], TT, TV, 0, .7, 1.2)); } else add(S + 'UpLeg', part(Ms.bottom, B[S + 'Leg'], TT, TV, 0, 1, .8)); }
        if (B[S + 'Foot']) { if (shorts) add(S + 'Leg', part(M.skin, B[S + 'Foot'], ST, SV, 0, 1)); else { add(S + 'Leg', part(Ms.bottom, B[S + 'Foot'], ST, [7, 7.1, 6.3, 6.0], 0, .95, 0)); add(S + 'Leg', part(M.skin, B[S + 'Foot'], ST, SV, .8, 1)); } }
        if (B[S + 'ToeBase']) add(S + 'Foot', capsule(Ms.shoes, B[S + 'ToeBase'], 5.2, 4.6)); add(S + 'ToeBase', ell(Ms.shoes, 4.8, 6.4, 3.6, 0, 3.2, 0));
      }
      // head: skull with a painted face, ears, nose, hair, beard, hat, glasses
      const H = new T.Group(); H.scale.setScalar(L.headSize); add('Head', H); this.headG = H; this.marksN = { head: 0, body: 0 };
      M.nose = (() => { const c = new T.Color(L.skin); c.multiplyScalar(.93); return new T.MeshPhongMaterial({ color: c, shininess: 14, specular: 0x1a1512 }); })(); const F = { jaw: L.jaw == null ? .5 : L.jaw, chin: L.chin == null ? .5 : L.chin, cheek: L.cheek == null ? .5 : L.cheek, ridge: L.browRidge == null ? .4 : L.browRidge, nose: L.noseSize || 1, noseW: L.noseWidth || 1, noseL: L.noseLength || 1, hook: L.noseBridge || 0, ears: L.earSize || 1 }; const rx = 8.9 * (L.faceWidth || 1), ry = 11.9 * (L.faceLength || 1), rz = 10.0, cy = 11.2, cz = 1.2, tex = new T.CanvasTexture(this._face(L)), tex2 = new T.CanvasTexture(this._face(L, true)); tex.anisotropy = tex2.anisotropy = 8;
      if (this.faceTex) for (const t of this.faceTex) t.dispose(); this.faceTex = [tex, tex2]; this.blinkT = 2 + Math.random() * 3;
      const headShape = (g, plain) => { const p = g.attributes.position, ss = (a, b, v) => { const t = clamp((v - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); }, taper = lerp(.52, .12, F.jaw);
        for (let i = 0; i < p.count; i++) { let x = p.getX(i), y = p.getY(i), z = p.getZ(i);
          if (y < 0) { const k = -y, sq = F.jaw * .1 * Math.sin(Math.min(1, k / .75) * Math.PI);                 // a wide jaw holds its width down to the angle, then turns in
            x *= 1 - taper * k * k + sq; z *= z > 0 ? 1 - .1 * k * k : 1 - .3 * k;
            if (z > 0) { const w = ss(.45, .95, k) * Math.min(1, z * 2.2) * (1 - Math.min(1, Math.abs(x) * 1.6)); z += w * (.1 + F.chin * .3); y -= w * (F.chin * .12); } }                      // the chin, forward and down
          else if (z > 0) z *= 1 - .05 * y;
          if (z > .15) { const ax = Math.abs(x), sx = x < 0 ? -1 : 1;
            { const d2 = (ax - .6) * (ax - .6) / .05 + (y + .1) * (y + .1) / .03, w = Math.exp(-d2) * (F.cheek - .3) * .13; x += sx * w * .8; z += w; }                                            // cheekbones
            { const d2 = (ax - .52) * (ax - .52) / .06 + (y + .42) * (y + .42) / .05, w = Math.exp(-d2) * (.5 - F.cheek) * -.05 * (F.cheek < .5 ? -1 : .6); x += sx * w; z += w * .6; }            // and how full or hollow the cheek below them is
            { const w = Math.exp(-(y - .12) * (y - .12) / .008) * ss(.25, .6, z) * (1 - Math.min(1, ax * 1.25)) * F.ridge * .07; z += w; } }                                                          // the ridge of the brow
          if (!plain && z > .2) { const ax = Math.abs(x), ns = F.nose, nw = F.noseW * (.82 + .18 * ns), y0 = .0, y1 = -.47 - .1 * (F.noseL - 1), t = (y0 - y) / (y0 - y1), pr = .215 * ns;
            if (t > -.15 && t < 1.45) { const tc = clamp(t, 0, 1), hgt = t <= 1 ? lerp(.035, pr, Math.pow(tc, 1.25)) + F.hook * .07 * Math.exp(-(t - .4) * (t - .4) / .03) : pr * Math.pow(Math.max(0, 1 - (t - 1) / .42), 1.5),          // the ridge climbs from between the eyes to the tip, then tucks back in underneath
                wid = (lerp(.075, .1, tc) + .035 * Math.exp(-(t - .9) * (t - .9) / .03)) * nw, sN = ax / wid, bell = sN < 1.6 ? Math.pow(Math.max(0, 1 - sN * sN / 2.56), 2) : 0, fade = t < 0 ? ss(-.15, 0, t) : 1; z += hgt * bell * fade; }
            { const d2 = (ax - .125 * nw) * (ax - .125 * nw) / (.0032 * nw) + (y - (y1 + .045)) * (y - (y1 + .045)) / .0035; z += Math.exp(-d2) * pr * .42; }                                                                            // the wings of the nostrils
            { const d2 = x * x / (.008 * nw) + (y - (y1 + .03)) * (y - (y1 + .03)) / .006; z += Math.exp(-d2) * pr * .2; }                                                                                                   // the ball of the tip
            { const d2 = (ax - .37) * (ax - .37) / .014 + (y + .035) * (y + .035) / .006; z -= Math.exp(-d2) * .045; }                                                                                                         // the eyes sit back in their sockets
            { const d2 = x * x / .035 + (y + .725) * (y + .725) / .0028; z += Math.exp(-d2) * (.022 + .018 * (L.lips || 1)); } }                                                                                               // and the lips stand a little proud
          p.setXYZ(i, x, y, z); } g.computeVertexNormals(); return g; };   // narrower jaw, flatter back of the neck
      const skull = this.skull = new T.Mesh(headShape(new T.SphereGeometry(1, 128, 96)), new T.MeshPhongMaterial({ map: tex, shininess: 10, specular: 0x161210 })); skull.scale.set(rx, ry, rz); skull.position.set(0, cy, cz); H.add(skull);
      H.add(ell(M.skin, 1 * F.ears, 2.5 * F.ears, 1.7 * F.ears, -rx + .15, cy - 2.2, cz - .8), ell(M.skin, 1 * F.ears, 2.5 * F.ears, 1.7 * F.ears, rx - .15, cy - 2.2, cz - .8));
      const mess = n => { let sd = ((L.wearSeed | 0) || 5) * 53 + 11; const R = () => ((sd = (sd * 1664525 + 1013904223) >>> 0) / 4294967296); for (let i = 0; i < n; i++) { const a = R() * 6.2832, e = .15 + R() * 1.15, nx = Math.sin(e) * Math.cos(a), ny = Math.cos(e), nz = Math.sin(e) * Math.sin(a) - .25, ln = 1.6 + R() * 2.2, q = ell(M.hair, 1.1 + R() * 1.2, ln, 1.0 + R() * 1.0, nx * rx * 1.05, cy + ny * ry * 1.05 + .3, cz + nz * rz * 1.05); q.quaternion.setFromUnitVectors(new T.Vector3(0, 1, 0), new T.Vector3(nx * .5 + (R() - .5) * 1.6, ny * .5 + (R() - .5) * .9, nz * .5 + (R() - .5) * 1.6).normalize()); H.add(q); } };   // tufts that stand out from the head at whatever angle they slept at
      const dome = (m, s, th, tilt, yo) => { const geo = new T.SphereGeometry(1, 24, 14, 0, 6.2832, 0, th); geo.rotateX(-tilt); const g = new T.Mesh(geo, m); g.scale.set(rx * s, ry * s, rz * s); g.position.set(0, cy + (yo || 0), cz); return g; };   // tipped back first, then stretched: the cap follows the skull whatever its shape
      const hs = L.hair;
      if (hs === 'buzz') H.add(dome(M.hair, 1.035, 1.5, .42));
      else if (hs === 'short') H.add(dome(M.hair, 1.07, 1.62, .5, .3));
      else if (hs === 'long') { H.add(dome(M.hair, 1.09, 1.7, .5, .3), ell(M.hair, 10.2, 15, 6.2, 0, cy - 7, cz - 5.4)); }
      else if (hs === 'ponytail') { H.add(dome(M.hair, 1.06, 1.62, .5, .3), ell(M.hair, 3, 3, 3, 0, cy + 4, cz - 10.6), ell(M.hair, 2.6, 9.5, 2.8, 0, cy - 5, cz - 12.5)); }
      else if (hs === 'bun') { H.add(dome(M.hair, 1.06, 1.62, .5, .3), ell(M.hair, 4.4, 4.2, 4.4, 0, cy + 11.5, cz - 5)); }
      else if (hs === 'afro') { const g = dome(M.hair, 1.38, 1.6, .62, 1.5); H.add(g); }
      else if (hs === 'mohawk') H.add(ell(M.hair, 1.5, 6.5, 10.5, 0, cy + 8.2, cz - 1.5), dome(M.hair, 1.015, 1.2, .5));
      if (L.wear > .3 && !L.noMess && hs !== 'bald' && hs !== 'buzz' && L.hat === 'none') mess(Math.round(4 + L.wear * 8));
      if (L.beard === 'full') { const g = new T.Mesh(headShape(new T.SphereGeometry(1, 20, 10, .35, 2.44, 1.78, 1.05), true), M.hair); g.scale.set(rx * 1.06, ry * 1.1, rz * 1.07); g.position.set(0, cy, cz); H.add(g); }
      if (L.hat === 'cap') { H.add(dome(M.hat, 1.1, 1.38, .32, .6)); H.add(ell(M.hat, 7.6, .7, 6.5, 0, cy + 6.6, cz + 12.2)); }
      else if (L.hat === 'beanie') { H.add(dome(M.hat, 1.1, 1.52, .38, .5), ell(M.hat, 2, 2, 2, 0, cy + 13.4, cz - 2)); }
      if (L.glasses) for (const sx of [-1, 1]) { const r = new T.Mesh(new T.TorusGeometry(2.5, .32, 6, 18), M.dark); r.scale.setScalar(1.06); r.position.set(sx * 3.95 * L.eyeSpacing, cy - .1, cz + rz - .55); r.rotation.y = sx * .38; H.add(r); if (sx > 0) { const br = new T.Mesh(new T.CylinderGeometry(.28, .28, 2.4, 6), M.dark); br.rotation.z = 1.5708; br.position.set(0, cy + .1, cz + rz - .1); H.add(br); } }
      H.traverse(q => { q.frustumCulled = false; });
      this.mats = Object.values(M).concat([skull.material], this._skinMats || []);
      this.holder.scale.setScalar(L.height);
      return this;
    }
    // Build the trunk as skinned tubes in the rig's bind pose: trousers to the waist, shirt to the collar, neck above.
    _torso(src, L, M, fat, bw, belly, limb) {
      const T = this.T, B = this.bones, sk = src.skeleton, V = () => new T.Vector3(), idx = n => sk.bones.indexOf(B[n]);
      for (const n of ['Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'Head', 'LeftArm', 'RightArm', 'LeftForeArm']) if (idx(n) < 0) return false;
      const P = n => V().setFromMatrixPosition(new T.Matrix4().copy(sk.boneInverses[idx(n)]).invert());
      const hips = P('Hips'), sp = P('Spine'), s1 = P('Spine1'), s2 = P('Spine2'), nk = P('Neck'), hd = P('Head'), la = P('LeftArm'), ra = P('RightArm');
      const u = la.distanceTo(P('LeftForeArm')) / B.LeftForeArm.position.length();                       // bind units per cm
      const up = hd.clone().sub(hips).normalize(), lx = la.clone().sub(ra); lx.addScaledVector(up, -lx.dot(up)).normalize(); const fr = V().crossVectors(lx, up).normalize();
      const sw = la.distanceTo(ra) / 2 / u, at = (p, dy) => p.clone().addScaledVector(up, dy * u), R = (c, rx, rf, rb, w) => ({ c, rx, rf: rf * 1.12, rb: rb * 1.1, w });
      const cr = (a, b, c, d, t) => .5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t);
      const inv = new T.Matrix4().copy(src.bindMatrix).invert(); this._skinMats = [];
      const tube = (rings, mat, cap0, cap1) => { const N = 22, K = 4, fine = [];
        for (let i = 0; i < rings.length - 1; i++) { const a = rings[Math.max(0, i - 1)], b = rings[i], c = rings[i + 1], d = rings[Math.min(rings.length - 1, i + 2)];
          for (let j = 0; j < (i === rings.length - 2 ? K + 1 : K); j++) { const t = j / K, w = {}; for (const k in b.w) w[k] = (w[k] || 0) + b.w[k] * (1 - t); for (const k in c.w) w[k] = (w[k] || 0) + c.w[k] * t;
            fine.push({ c: V().set(cr(a.c.x, b.c.x, c.c.x, d.c.x, t), cr(a.c.y, b.c.y, c.c.y, d.c.y, t), cr(a.c.z, b.c.z, c.c.z, d.c.z, t)), rx: cr(a.rx, b.rx, c.rx, d.rx, t), rf: cr(a.rf, b.rf, c.rf, d.rf, t), rb: cr(a.rb, b.rb, c.rb, d.rb, t), w }); } }
        const pos = [], uvs = [], si = [], wt = [], ix = [], put = (p, w, uu, vv) => { pos.push(p.x, p.y, p.z); uvs.push(uu == null ? .5 : uu, vv == null ? .5 : vv); const e = Object.entries(w).filter(q => q[1] > .001).sort((x, y) => y[1] - x[1]).slice(0, 4), tot = e.reduce((s, q) => s + q[1], 0); for (let k = 0; k < 4; k++) { si.push(e[k] ? idx(e[k][0]) : 0); wt.push(e[k] ? e[k][1] / tot : 0); } };
        fine.forEach((r, fi) => { for (let j = 0; j < N; j++) { const th = j / N * 6.2832, sn = Math.sin(th); put(r.c.clone().addScaledVector(lx, Math.cos(th) * r.rx * u).addScaledVector(fr, sn * (sn > 0 ? r.rf : r.rb) * u), r.w, j / N, .08 + .84 * fi / (fine.length - 1)); } });
        for (let i = 0; i < fine.length - 1; i++) for (let j = 0; j < N; j++) { const A = i * N + j, Bq = i * N + (j + 1) % N, C = A + N, D = Bq + N; ix.push(A, C, Bq, Bq, C, D); }
        if (cap0) { const c = pos.length / 3; put(fine[0].c, fine[0].w); for (let j = 0; j < N; j++) ix.push(c, j, (j + 1) % N); }
        if (cap1) { const c = pos.length / 3, o = (fine.length - 1) * N; put(fine[fine.length - 1].c, fine[fine.length - 1].w); for (let j = 0; j < N; j++) ix.push(c, o + (j + 1) % N, o + j); }
        const g = new T.BufferGeometry(); g.setAttribute('position', new T.Float32BufferAttribute(pos, 3)); g.setAttribute('uv', new T.Float32BufferAttribute(uvs, 2)); g.setAttribute('skinIndex', new T.Uint16BufferAttribute(si, 4)); g.setAttribute('skinWeight', new T.Float32BufferAttribute(wt, 4)); g.setIndex(ix); g.applyMatrix4(inv); g.computeVertexNormals();
        const m = mat.clone(); m.skinning = true; this._skinMats.push(m); const mesh = new T.SkinnedMesh(g, m); mesh.position.copy(src.position); mesh.quaternion.copy(src.quaternion); mesh.scale.copy(src.scale); src.parent.add(mesh); mesh.bind(sk, src.bindMatrix); mesh.frustumCulled = false; this.parts.push(mesh); };
      const H = { Hips: 1 }, tuck = !!L.belt;
      tube([R(at(hips, -15), 5 * fat, 4.5, 4.5, H), R(at(hips, -11), 12.6 * fat, 8.4, 9.4 * fat, H), R(at(hips, -5), 16 * fat, 9.6 * fat, 11.2 * fat, H), R(at(hips, 2), 15.6 * fat, 9.9 * belly, 10.4 * fat, H), R(at(hips, 9), 14.5 * fat, 9.8 * belly, 9.4 * fat, { Hips: .55, Spine: .45 })], M.bottom, true, true);
      if (tuck) tube([R(at(hips, 6.4), 15.3 * fat, 10.3 * belly, 10.1 * fat, H), R(at(hips, 7.8), 15.5 * fat, 10.6 * belly, 10.3 * fat, { Hips: .7, Spine: .3 }), R(at(hips, 9.4), 15.1 * fat, 10.4 * belly, 9.9 * fat, { Hips: .55, Spine: .45 })], M.belt, true, true);
      const hem = tuck ? [R(at(hips, 8), 14.3 * fat, 9.6 * belly, 9.2 * fat, { Hips: .6, Spine: .4 })] : [R(at(hips, 1.5), 16.5 * fat, 10.6 * belly, 11.2 * fat, H), R(at(hips, 8), 15.3 * fat, 10.5 * belly, 10.1 * fat, { Hips: .6, Spine: .4 })];
      tube(hem.concat([R(at(sp, 4), 14.3 * fat, 9.9 * belly, 9.2 * fat, { Spine: 1 }), R(s1, 14.9 * fat, 10.3 * lerp(1, belly, .5) * fat, 9.5 * fat, { Spine: .5, Spine1: .5 }), R(at(s1, 6), 15.8 * bw, 10.9 * fat, 9.9 * fat, { Spine1: 1 }),
        R(s2, 16.6 * bw, 11.3 * fat, 10.1 * fat, { Spine1: .5, Spine2: .5 }), R(at(s2, 7), Math.max(16.6 * bw, sw + 1.2), 10.9 * fat, 10.2 * fat, { Spine2: 1 }), R(at(s2, 11.2), Math.max(15, sw - .5), 8.6, 8.8, { Spine2: 1 }),
        R(at(s2, 13.8), sw * .58, 6.8, 7.2, { Spine2: 1 }), R(at(nk, 1.2), 6.7 * limb, 6.1 * limb, 6.5 * limb, { Spine2: .5, Neck: .5 })]), M.top, true, false);
      tube([R(at(s2, 11), 7 * limb, 6.4 * limb, 6.6 * limb, { Spine2: 1 }), R(nk, 5.7 * limb, 5.5 * limb, 5.7 * limb, { Spine2: .5, Neck: .5 }), R(hd, 5.2 * limb, 5.3 * limb, 5.4 * limb, { Neck: .5, Head: .5 }), R(at(hd, 5), 5 * limb, 5.2 * limb, 5.2 * limb, { Head: 1 })], M.skin, false, false);
      return true;
    }
    // paint the face onto the head texture (front of the head is at x = 128 of 512)
    _face(L, closed) {
      const c = document.createElement('canvas'); c.width = 1024; c.height = 512; const g = c.getContext('2d'), cx = 128; g.scale(2, 2);
      let sd = 0; for (const ch of String(L.skin) + L.hairColor + L.hair + (L.top || '')) sd = (sd * 31 + ch.charCodeAt(0)) >>> 0; const R = () => ((sd = (sd * 1664525 + 1013904223) >>> 0) / 4294967296);
      const age = L.age == null ? .35 : L.age, grime = L.grime || 0, tired = L.tired == null ? .3 : L.tired;
      g.fillStyle = L.skin; g.fillRect(0, 0, 512, 256);
      // skin is never one colour: mottling, then pores
      for (let i = 0; i < 90; i++) { const x = R() * 512, y = R() * 256, r = 6 + R() * 16; const gr = g.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, R() < .5 ? 'rgba(190,80,60,.045)' : 'rgba(255,240,220,.04)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2); }
      for (let i = 0; i < 1500; i++) { g.fillStyle = R() < .6 ? 'rgba(60,25,15,.07)' : 'rgba(255,245,235,.06)'; g.fillRect(R() * 256, 40 + R() * 200, .5, .5); }
      g.translate(0, 17); g.translate(cx, 138); g.scale(1.2, 1.16); g.translate(-cx, -138);   // the features take up as much of the head as a real face does
      const shade = (x, y, rx, ry, col) => { const gr = g.createRadialGradient(x, y, 0, x, y, rx); gr.addColorStop(0, col); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.save(); g.translate(x, y); g.scale(1, ry / rx); g.translate(-x, -y); g.fillStyle = gr; g.fillRect(x - rx, y - rx, rx * 2, rx * 2); g.restore(); };
      const ex = 26 * L.eyeSpacing, ey = 117, ew = 12.2 * L.eyeSize, eh = 6.0 * L.eyeSize;
      // the planes of the face: lit forehead, cheekbones and bridge; shadow at the temples, the sockets, under nose, lip and jaw
      shade(cx, 84, 46, 22, 'rgba(255,240,225,.12)'); shade(cx - 34, 138, 20, 11, 'rgba(255,235,220,.12)'); shade(cx + 34, 138, 20, 11, 'rgba(255,235,220,.12)'); shade(cx, 122, 5, 16, 'rgba(255,240,225,.12)');
      shade(cx - 70, 120, 30, 70, 'rgba(40,15,5,.16)'); shade(cx + 70, 120, 30, 70, 'rgba(40,15,5,.16)'); shade(cx, 208, 62, 26, 'rgba(40,15,5,.18)');
      shade(cx - 40, 160, 20, 22, 'rgba(60,25,15,.10)'); shade(cx + 40, 160, 20, 22, 'rgba(60,25,15,.10)');                                         // the hollow under each cheekbone
      shade(cx - 36, 150, 20, 12, 'rgba(205,85,75,.11)'); shade(cx + 36, 150, 20, 12, 'rgba(205,85,75,.11)');
      shade(cx - ex, ey - 4, ew + 10, eh + 12, 'rgba(50,20,10,.26)'); shade(cx + ex, ey - 4, ew + 10, eh + 12, 'rgba(50,20,10,.26)');
      shade(cx - ex + 2, ey + 9, ew + 2, 4.6, `rgba(80,35,55,${(.1 + .2 * tired).toFixed(3)})`); shade(cx + ex - 2, ey + 9, ew + 2, 4.6, `rgba(80,35,55,${(.1 + .2 * tired).toFixed(3)})`);   // the nights show under the eyes
      shade(cx - 9, 128, 7, 24, 'rgba(50,20,10,.07)'); shade(cx + 9, 128, 7, 24, 'rgba(50,20,10,.07)'); shade(cx, 160, 11, 4, 'rgba(50,20,10,.1)'); shade(cx, 164, 3.4, 5, 'rgba(50,20,10,.12)');
      g.lineCap = 'round';
      if (age > .15) { g.strokeStyle = `rgba(70,30,18,${(.1 + .22 * age).toFixed(3)})`; g.lineWidth = 1.1; for (const sx of [-1, 1]) { g.beginPath(); g.moveTo(cx + sx * 8.5, 151); g.quadraticCurveTo(cx + sx * 17, 160, cx + sx * 17.5, 174); g.stroke(); }      // the fold from nose to mouth
        g.strokeStyle = `rgba(70,30,18,${(.05 + .16 * age).toFixed(3)})`; g.lineWidth = .9; for (let k = 0; k < 3; k++) { g.beginPath(); g.moveTo(cx - 26 + k * 3, 82 + k * 6.5); g.quadraticCurveTo(cx, 79 + k * 6.5 + R() * 2, cx + 26 - k * 3, 82 + k * 6.5); g.stroke(); }
        for (const sx of [-1, 1]) for (let k = 0; k < 3; k++) { g.beginPath(); g.moveTo(cx + sx * (ex + ew + 1), ey + 1 + k * .6); g.lineTo(cx + sx * (ex + ew + 6), ey - 2 + k * 3.2); g.stroke(); }
        g.beginPath(); g.moveTo(cx - 2.2, 96); g.lineTo(cx - 2.6, 104); g.moveTo(cx + 2.2, 96); g.lineTo(cx + 2.6, 104); g.stroke(); }                                                                             // and the two between the brows
      if (L.beard === 'stubble' || L.beard === 'full') { g.globalAlpha = L.beard === 'full' ? .8 : .22; g.fillStyle = L.hairColor; g.beginPath(); g.ellipse(cx, 182, 50, 42, 0, 0, 6.2832); g.fill(); g.globalAlpha = 1; g.fillStyle = L.skin; g.beginPath(); g.ellipse(cx, 168, 15, 6.5, 0, 0, 6.2832); g.fill();
        g.strokeStyle = L.hairColor; g.lineWidth = .6; g.globalAlpha = L.beard === 'full' ? .7 : .55; for (let i = 0; i < (L.beard === 'full' ? 900 : 700); i++) { const a = R() * 6.2832, rr = Math.sqrt(R()), x = cx + Math.cos(a) * rr * 52, y = 184 + Math.sin(a) * rr * 44; if (Math.hypot((x - cx) / 15, (y - 168) / 6.5) < 1 || y < 148) continue; g.beginPath(); g.moveTo(x, y); g.lineTo(x + (R() - .5) * 1.2, y + 1.2 + R() * (L.beard === 'full' ? 3 : 1)); g.stroke(); } g.globalAlpha = 1; }
      for (const sx of [-1, 1]) { const x = cx + sx * ex; g.save(); g.translate(x, ey); g.rotate(-sx * (L.eyeTilt || 0)); g.translate(-x, -ey); const almond = () => { g.beginPath(); g.moveTo(x - ew, ey + .9); g.quadraticCurveTo(x - sx * 1.5, ey - eh * 1.75, x + ew, ey + .9 - sx * .0); g.quadraticCurveTo(x, ey + eh * 1.3, x - ew, ey + .9); };
        if (closed) { g.strokeStyle = 'rgba(30,16,10,.8)'; g.lineWidth = 1.8; g.beginPath(); g.moveTo(x - ew, ey + .6); g.quadraticCurveTo(x, ey + eh * 1.1, x + ew, ey + .6); g.stroke(); g.lineWidth = .7; for (let k = 0; k < 9; k++) { const t = k / 8, lx = x - ew + ew * 2 * t, ly = ey + .6 + Math.sin(t * Math.PI) * eh * .55; g.beginPath(); g.moveTo(lx, ly); g.lineTo(lx + (t - .5) * 2, ly + 2); g.stroke(); } }
        else { almond(); g.fillStyle = '#e9e3dc'; g.fill();
          g.save(); almond(); g.clip();
          { const gr = g.createLinearGradient(x - ew, 0, x + ew, 0); gr.addColorStop(0, 'rgba(120,70,70,.4)'); gr.addColorStop(.22, 'rgba(120,70,70,0)'); gr.addColorStop(.78, 'rgba(120,70,70,0)'); gr.addColorStop(1, 'rgba(120,70,70,.4)'); g.fillStyle = gr; g.fillRect(x - ew, ey - eh * 2, ew * 2, eh * 4); }   // the white is not white at the corners
          const ir = eh * 1.06, iy = ey - .5, ig = g.createRadialGradient(x, iy, ir * .25, x, iy, ir); ig.addColorStop(0, L.eyeColor); ig.addColorStop(.55, L.eyeColor); ig.addColorStop(.86, 'rgba(0,0,0,.25)'); ig.addColorStop(1, 'rgba(8,6,6,.95)');
          g.fillStyle = L.eyeColor; g.beginPath(); g.arc(x, iy, ir, 0, 6.2832); g.fill(); g.strokeStyle = 'rgba(255,255,255,.2)'; g.lineWidth = .35; for (let k = 0; k < 22; k++) { const a = k / 22 * 6.2832 + R(); g.beginPath(); g.moveTo(x + Math.cos(a) * ir * .45, iy + Math.sin(a) * ir * .45); g.lineTo(x + Math.cos(a) * ir * .9, iy + Math.sin(a) * ir * .9); g.stroke(); }   // the fibres of the iris
          g.fillStyle = ig; g.beginPath(); g.arc(x, iy, ir, 0, 6.2832); g.fill(); g.fillStyle = '#060505'; g.beginPath(); g.arc(x, iy, ir * .42, 0, 6.2832); g.fill();
          g.fillStyle = 'rgba(30,14,8,.36)'; g.fillRect(x - ew, ey - eh * 2, ew * 2, eh * 1.3);                                                      // the lid's shadow on the eye
          g.fillStyle = 'rgba(255,255,255,.9)'; g.beginPath(); g.arc(x + 1.9, ey - 1.9, 1.05, 0, 6.2832); g.fill(); g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.arc(x - 1.6, ey + 1.2, .6, 0, 6.2832); g.fill(); g.restore();
          g.fillStyle = 'rgba(200,110,110,.75)'; g.beginPath(); g.arc(x - sx * (ew - 1.3), ey + .9, 1.15, 0, 6.2832); g.fill();                         // the corner by the nose
          g.strokeStyle = 'rgba(210,140,130,.5)'; g.lineWidth = .8; g.beginPath(); g.moveTo(x - ew + 1, ey + 1.4); g.quadraticCurveTo(x, ey + eh * 1.42, x + ew - 1, ey + 1.4); g.stroke();                       // the wet edge of the lower lid
          g.strokeStyle = 'rgba(20,10,8,.92)'; g.lineWidth = 1.9; g.beginPath(); g.moveTo(x - ew, ey + .9); g.quadraticCurveTo(x - sx * 1.5, ey - eh * 1.75, x + ew, ey + .9); g.stroke();                       // lash line
          g.lineWidth = .7; for (let k = 0; k < 8; k++) { const t = (k + .5) / 8, u = sx > 0 ? t : 1 - t, lx = x - ew + ew * 2 * t, ly = ey + .9 - Math.sin(t * Math.PI) * eh * 1.3, ln = .6 + u * 1.2; g.beginPath(); g.moveTo(lx, ly); g.lineTo(lx + sx * u * 1.4, ly - ln); g.stroke(); } }   // lashes, longer at the outer corner
        g.strokeStyle = 'rgba(60,25,15,.36)'; g.lineWidth = 1.1; g.beginPath(); g.moveTo(x - ew * .95, ey - eh * 1.45); g.quadraticCurveTo(x, ey - eh * 2.6, x + ew * .95, ey - eh * 1.4); g.stroke();                     // crease of the lid
        // a brow is hairs, not a line: laid along the arch, thick by the nose and thinning out
        { const bt = L.browTilt * 3.5, bx0 = x - sx * (ew + 3), by0 = ey - 13 + bt, bx1 = x + sx * (ew + 5), by1 = ey - 12.5 - bt, mxp = x, myp = ey - 18.5 - L.brow; g.strokeStyle = L.hairColor;
          for (let k = 0; k < 70; k++) { const t = R(), it = 1 - t, px = it * it * bx0 + 2 * it * t * mxp + t * t * bx1, py = it * it * by0 + 2 * it * t * myp + t * t * by1, th = (1.9 - 1.3 * t) * L.brow, oy = (R() - .5) * 2 * th, ln = 2.4 + R() * 2.2; g.globalAlpha = .45 + R() * .5; g.lineWidth = .55 + R() * .5; g.beginPath(); g.moveTo(px, py + oy); g.lineTo(px + sx * ln, py + oy - ln * (.5 - t * .75)); g.stroke(); } g.globalAlpha = 1; } g.restore(); }
      g.fillStyle = 'rgba(40,12,8,.42)'; g.beginPath(); { const nwT = (L.noseWidth || 1) * (.8 + .2 * (L.noseSize || 1)), nyT = 152.5 + ((L.noseLength || 1) - 1) * 12; g.ellipse(cx - 4.4 * nwT, nyT + 1.5, 2.1 * nwT, 1.2, .3, 0, 6.2832); g.ellipse(cx + 4.4 * nwT, nyT + 1.5, 2.1 * nwT, 1.2, -.3, 0, 6.2832); } g.fill();                                               // nostrils
      const lf = L.lips || 1, my = 171, mw = 15.5 * (L.mouthWidth || 1), sm = L.mouth * 6, yE = my - sm * .5, yM = my + sm * .5;
      g.fillStyle = L.lipColor; g.beginPath(); g.moveTo(cx - mw, yE); g.quadraticCurveTo(cx - 6, yM - 5.4 * lf, cx - 2.5, yM - 3.8 * lf); g.lineTo(cx, yM - 2.7 * lf); g.lineTo(cx + 2.5, yM - 3.8 * lf); g.quadraticCurveTo(cx + 6, yM - 5.4 * lf, cx + mw, yE); g.quadraticCurveTo(cx, yM + 1, cx - mw, yE); g.fill();   // upper lip
      g.fillStyle = 'rgba(30,8,6,.28)'; g.fill();
      g.fillStyle = L.lipColor; g.beginPath(); g.moveTo(cx - mw, yE); g.quadraticCurveTo(cx, yM + 1, cx + mw, yE); g.quadraticCurveTo(cx, yM + 9.8 * lf, cx - mw, yE); g.fill(); shade(cx, yM + 3.6, 8, 2.2, 'rgba(255,235,230,.3)');                                        // lower lip, with a little light on it
      g.save(); g.beginPath(); g.moveTo(cx - mw, yE); g.quadraticCurveTo(cx - 6, yM - 5.4, cx, yM - 2.7); g.quadraticCurveTo(cx + 6, yM - 5.4, cx + mw, yE); g.quadraticCurveTo(cx, yM + 9.8 * lf, cx - mw, yE); g.clip(); g.strokeStyle = 'rgba(60,15,12,.2)'; g.lineWidth = .45; for (let k = 0; k < 16; k++) { const lx = cx - mw + 2 + k * (mw * 2 - 4) / 15 + (R() - .5); g.beginPath(); g.moveTo(lx, yM - 5); g.lineTo(lx + (R() - .5) * 1.5, yM + 9); g.stroke(); } g.restore();   // the fine lines of the lips
      g.strokeStyle = 'rgba(35,10,8,.8)'; g.lineWidth = 1.3; g.beginPath(); g.moveTo(cx - mw, yE); g.quadraticCurveTo(cx, yM + 1, cx + mw, yE); g.stroke(); shade(cx - mw - .5, yE, 2.6, 2.6, 'rgba(40,12,8,.35)'); shade(cx + mw + .5, yE, 2.6, 2.6, 'rgba(40,12,8,.35)'); shade(cx, yM + 13, 14, 4.5, 'rgba(50,20,10,.2)');
      if (L.beard === 'mustache' || L.beard === 'full') { g.strokeStyle = L.hairColor; g.lineWidth = 5.5; g.beginPath(); g.moveTo(cx - 17, 165); g.quadraticCurveTo(cx, 157.5, cx + 17, 165); g.stroke(); g.lineWidth = .6; for (let i = 0; i < 120; i++) { const t = R(), px = cx - 18 + 36 * t, py = 165 - Math.sin(t * Math.PI) * 6.6 + (R() - .5) * 5; g.beginPath(); g.moveTo(px, py); g.lineTo(px + (t - .5) * 2.4, py + 2.6); g.stroke(); } }
      if (L.freckles) { g.fillStyle = 'rgba(120,60,30,.4)'; for (let i = 0; i < 60; i++) { const a = R() * 6.2832, r = Math.sqrt(R()) * 30; g.beginPath(); g.arc(cx + Math.cos(a) * r * 1.3, 143 + Math.sin(a) * r * .42, .5 + R() * .7, 0, 6.2832); g.fill(); } }
      if (grime > 0) { for (let i = 0; i < 7; i++) shade(cx + (R() - .5) * 110, 70 + R() * 130, 8 + R() * 16, 5 + R() * 12, `rgba(40,30,22,${(grime * (.08 + R() * .16)).toFixed(3)})`); g.strokeStyle = `rgba(40,30,22,${(grime * .22).toFixed(3)})`; g.lineWidth = 2.2; for (let i = 0; i < 2; i++) { const x0 = cx + (R() - .5) * 70, y0 = 90 + R() * 80; g.beginPath(); g.moveTo(x0, y0); g.lineTo(x0 + 8 + R() * 10, y0 + (R() - .5) * 6); g.stroke(); } }   // weeks without a wash
      return c;
    }

    // ================= moves =================
    /** Start a move. Returns false if one is already playing. opts.facing optionally turns first. */
    play(name, opts) {
      const d = MOVES[name]; if (!d || this.climbing || this.ko || this.hang || this.swimming) return false;
      const cur = this.action;
      if (cur) { if (!(d.strike && cur.def.strike)) return false;
        if (cur.t < cur.def.chain) { this.queued = name; this.queuedOpts = opts; this.queueT = 0.35; return false; }       // too early: remember it and throw it when the current strike allows
        this.combo++; } else this.combo = d.strike ? 1 : 0;
      if (d.air && !this.grounded) return false;
      const tg = this._target(d, opts);
      if (tg) { this.faceToward(tg.x);                                                              // the two turn to face each other
        if (tg.engage) { this.engage(tg, d.dur + 0.8); if (!(opts && opts.turnOther === false)) tg.engage(this, d.dur + 1.2); if (d.answer && !(opts && opts.noAnswer) && !tg.busy && !tg.down) tg._pending = { name: d.answer, t: d.dur * 0.3, from: this }; } }
      else if (opts && opts.facing) this.facing = opts.facing; else if (d.face) this.facing = d.face;
      let dur = d.dur * (cur ? 0.84 : 1) / clamp(opts && opts.speed || 1, 0.4, 2.5); const dir = this.facing === 'left' ? -1 : this.facing === 'right' ? 1 : 0;
      if (d.air) { const o = this.o, dr = dir || 1; this.vy = o.jumpSpeed * d.vy; this.vx = dr * o.walkSpeed * d.vx; this.grounded = false; this.airTime = .2; dur = 2 * this.vy / o.gravity; if (this.facing === 'front' || this.facing === 'back') this.facing = 'right'; }
      if (d.lunge && this.grounded) this.vx += dir * this.o.walkSpeed * d.lunge;                    // step into the blow
      this.queued = null; this._blend(); this.action = { name, def: d, t: 0, dur }; if (d.start) d.start(this); return true;
    }
    _target(d, opts) {
      if (opts && opts.facing) return null; if (opts && opts.target !== undefined) return typeof opts.target === 'number' ? { x: opts.target } : opts.target;
      if (!(d.strike || d.social)) return null; let best = d.social ? d.range || 4 : 2.2, tg = null;
      for (const a of this.actors || []) { const dx = Math.abs(a.x - this.x); if (a !== this && !a.ko && dx < best && Math.abs(a.y - this.y) < 1.2) { best = dx; tg = a; } } return tg;
    }
    /** Turn left or right to look at world x. */
    faceToward(x) { if (Math.abs(x - this.x) > 0.01) this.facing = x > this.x ? 'right' : 'left'; return this; }
    /** Stay turned toward another character for sec seconds (whenever not walking somewhere else). */
    engage(other, sec) { this.focus = other && other !== this ? { o: other, t: sec || 1.5 } : null; return this; }
    get engaged() { return this.focus ? this.focus.o : null; }
    static faceEachOther(a, b, sec) { a.faceToward(b.x); b.faceToward(a.x); a.engage(b, sec); b.engage(a, sec); }
    /** Cross-fade from the pose on screen into whatever comes next, so moves flow into each other. */
    _blend() { for (let i = 0; i < this.blist.length; i++) this.snapQ[i].copy(this.lastQ[i]); this.blendW = 1; }
    /** Where a bone is, in world units relative to the character's feet: [x, y]. For effects such as trails. */
    bonePos(name) { const b = this.bones[name]; if (!b) return null; const v = b.getWorldPosition(this._iv[0]); return [v.x, v.y]; }
    /** Tip of the held item (the sword's point), same units as bonePos, or null. */
    itemTip() { const u = this.held && this.held.obj.userData.tip; if (!u) return null; u[0].updateWorldMatrix(true, false); const v = u[0].localToWorld(this._iv[0].set(0, u[1], 0)); return [v.x, v.y]; }
    get busy() { return !!this.action; }
    _axis(k) { const h = this.heading + this.yaw; return k === 'R' ? this._ax.set(Math.cos(h), 0, -Math.sin(h)) : k === 'F' ? this._ax.set(Math.sin(h), 0, Math.cos(h)) : this._ax.set(0, 1, 0); }
    _rot(n, ax, ang) { const bone = this.bones[n]; if (!bone || !ang) return; bone.parent.getWorldQuaternion(this._q1); this._q2.setFromAxisAngle(ax, ang); this._q3.copy(this._q1).invert().multiply(this._q2).multiply(this._q1); bone.quaternion.premultiply(this._q3); }
    _R(n, a) { this._rot(n, this._axis('R'), a); }   // pitch: + bends forward / swings back, - lifts forward
    _F(n, a) { this._rot(n, this._axis('F'), a); }   // roll about the forward axis
    _U(n, a) { this._rot(n, this._axis('U'), a); }   // twist about vertical
    /** Jump: a leap on the way up, reaching for the floor on the way down. r = vy / jumpSpeed. */
    _airPose(k, r) {
      const u = sstep(-0.45, 0.45, r), d = 1 - u;   // u = rising, d = falling
      this._R('RightUpLeg', k * (-1.25 * u - 0.5 * d)); this._R('RightLeg', k * (1.55 * u + 0.6 * d));
      this._R('LeftUpLeg', k * (0.4 * u - 0.1 * d)); this._R('LeftLeg', k * (0.75 * u + 0.35 * d));
      this._R('LeftFoot', k * 0.45 * u); this._R('RightFoot', k * 0.25);
      this._R('LeftArm', k * (-1.5 * u - 1.0 * d)); this._R('LeftForeArm', k * (-0.9 * u - 0.3 * d));
      this._R('RightArm', k * (0.6 * u - 0.45 * d)); this._R('RightForeArm', k * (-0.8 * u - 0.3 * d));
      this._F('LeftArm', k * 0.55 * d); this._F('RightArm', -k * 0.55 * d);   // arms spread a little for balance on the way down
      this._R('Spine', k * (0.12 * u + 0.1 * d)); this._R('Neck', k * (-0.1 * u + 0.15 * d));
    }
    /** Foot placement: drop the hips to the lower foot, bend each leg so its ankle sits on the floor under it,
        tilt the feet to the slope and lean the body into a climb. On stairs the feet follow the stair stride instead. */
    _feet(dt, ground, dir, gait, plant) {
      const w = this.ikW, v = this._iv, S = ['Left', 'Right'], G = [0, 0], A = [0, 0], sw = gait ? this.stairW : 0;
      this.holder.updateMatrixWorld(true);
      for (let i = 0; i < 2; i++) { const ft = this.bones[S[i] + 'Foot']; if (!ft || !ground) continue; const fx = ft.getWorldPosition(v[0]).x;
        let g = ground(fx); const g2 = ground(fx + dir * 0.16 * clamp(this.speed / 1.5, 0, 1)); if (g2 - g > 0.2) g = g2;   // toe is about to meet a riser: lift early
        if (g < -0.5) g = 0;                                                                         // a drop-off, not a step: leave the foot level
        const sl = (ground(fx + 0.12) - ground(fx - 0.12)) / 0.24; A[i] = Math.abs(sl) > 1.2 ? 0 : Math.atan(sl);
        G[i] = clamp(g - this.stepOff, -0.5, 0.5); }
      const kf2 = Math.min(1, dt * 22);
      for (let i = 0; i < 2; i++) { this.footG[i] += (G[i] - this.footG[i]) * kf2; this.footA[i] += (A[i] - this.footA[i]) * Math.min(1, dt * 14); }
      this.pelv += (lerp(clamp(Math.min(this.footG[0], this.footG[1]), -0.45, 0.2), -0.1, sw) - (plant ? 0.1 * clamp(this.pl.spread / 0.6, 0, 1) * plant.w : 0) - this.pelv) * Math.min(1, dt * 14);
      const sb = ground ? clamp((ground(0.3) - ground(-0.3)) / 0.6, -1, 1) : 0;
      this.lean += (sb * dir * clamp(this.speed / 2, 0, 1) - this.lean) * Math.min(1, dt * 8);
      if (Math.abs(this.lean) > 0.01) { this._R('Spine', w * this.lean * 0.32); this._R('Neck', -w * this.lean * 0.12); }
      this.spin.position.y += w * this.pelv; this.holder.updateMatrixWorld(true);
      let sp = 0;
      for (let i = 0; i < 2; i++) { const ft = this.bones[S[i] + 'Foot']; if (!ft) continue; const c = ft.getWorldPosition(v[0]);
        let tx = c.x, ty = c.y + w * (this.footG[i] - this.pelv);
        if (gait) { tx = lerp(tx, gait.X[i], sw * w); ty = lerp(ty, gait.Y[i], sw * w); }
        if (plant) { const P = this.pl;                                   // during a move the feet stay where they are on the ground, and step when the body gets away from them
          if (i === plant.skip) { P.wx[i] = null; P.st[i] = null; }
          else { if (P.wx[i] === null) P.wx[i] = plant.x + c.x; const st = P.st[i]; let lift = 0;
            if (st) { st.t += dt / 0.13; const q = Math.min(1, st.t); P.wx[i] = lerp(st.from, st.to, sstep(0, 1, q)); lift = 0.1 * Math.sin(Math.PI * q); if (q >= 1) P.st[i] = null; }
            else if (!P.st[1 - i] && Math.abs(P.wx[i] - plant.x - c.x) > 0.3) P.st[i] = { t: 0, from: P.wx[i], to: plant.x + c.x + clamp((this.vx || 0) * 0.09, -0.22, 0.22) };
            sp += Math.abs(P.wx[i] - plant.x - c.x); tx = lerp(tx, P.wx[i] - plant.x, plant.w * w); ty += lift * plant.w; } }
        this._legIK(S[i], tx, ty, w * this.footA[i] * (1 - sw)); }
      if (plant) this.pl.spread = sp;
    }
    /** Where each foot should be on a flight of stairs. Walking lands on every tread, running on every other one.
        Each foot is planted on the middle of a tread while the body passes over it, then swings to its next tread. */
    _gait(st, x, dir, s, ground) {
      const o = this.o, tw = (st.x1 - st.x0) / st.steps, r = Math.abs(st.y1 - st.y0) / st.steps, nW = Math.max(1, Math.round(0.55 / tw));
      if (s > o.stairRunSpeed + 0.25) this.stairRun = true; else if (s < o.stairRunSpeed - 0.25) this.stairRun = false;
      const L = tw * nW * (this.stairRun ? 2 : 1), duty = this.stairRun ? 0.4 : 0.62, base = st.x0 + tw / 2, g = this._g || (this._g = { f: [0, 0], X: [0, 0], Y: [0, 0], run: false });
      g.run = this.stairRun;
      for (let i = 0; i < 2; i++) { const sp = dir * (x - base) / (2 * L) - i / 2 + duty / 2, k = Math.floor(sp), f = sp - k, X0 = base + dir * (2 * k + i) * L; g.f[i] = f;
        if (f < duty) { g.X[i] = X0 - x; g.Y[i] = ground(X0 - x) + this.ankleH; }
        else { const q = (f - duty) / (1 - duty), X1 = X0 + dir * 2 * L, e = sstep(0, 1, q), h0 = ground(X0 - x), h1 = ground(X1 - x);
          g.X[i] = lerp(X0, X1, e) - x; g.Y[i] = lerp(h0, h1, e) + this.ankleH + (0.1 + 0.7 * r) * Math.sin(Math.PI * q); } }
      return g;
    }
    /** Two-bone IK in the sprite's own space: put the end bone at (tx, ty), bending the middle joint the way flex says
        (1 = knee, -1 = elbow). keep = hold the end bone's orientation. */
    _ik2(upN, loN, endN, tx, ty, flex, keep) {
      const up = this.bones[upN], lo = this.bones[loN], ft = this.bones[endN]; if (!up || !lo || !ft) return;
      const v = this._iv, q = this._iq, a = up.getWorldPosition(v[0]), b = lo.getWorldPosition(v[1]), c = ft.getWorldPosition(v[2]);
      if (Math.abs(tx - c.x) + Math.abs(ty - c.y) < 0.002) return;
      if (keep) ft.getWorldQuaternion(q[0]);
      const l1 = a.distanceTo(b), l2 = b.distanceTo(c), t = v[3].set(tx, ty, c.z);
      const d = clamp(a.distanceTo(t), 0.08, (l1 + l2) * 0.999);
      const cur = v[4].copy(a).sub(b).angleTo(v[5].copy(c).sub(b)), want = Math.acos(clamp((l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2), -1, 1));
      this._rot(loN, this._axis('R'), flex * (cur - want));                                          // bend or straighten the middle joint
      up.updateWorldMatrix(false, true); ft.getWorldPosition(c);
      q[1].setFromUnitVectors(v[4].copy(c).sub(a).normalize(), v[5].copy(t).sub(a).normalize());     // swing the upper bone so the end lands on target
      up.parent.getWorldQuaternion(q[2]); up.quaternion.premultiply(q[1].premultiply(q[3].copy(q[2]).invert()).multiply(q[2]));
      up.updateWorldMatrix(false, true);
      if (keep) { ft.parent.getWorldQuaternion(q[2]); ft.quaternion.copy(q[2].invert()).multiply(q[0]); }
    }
    /** Leg IK: ankle to (tx, ty), foot orientation kept, then the foot pitched by ang. */
    _legIK(S, tx, ty, ang) { this._ik2(S + 'UpLeg', S + 'Leg', S + 'Foot', tx, ty, 1, true); if (Math.abs(ang) > 0.005) this._rot(S + 'Foot', this._zAx, ang); }
    /** Ask for a hand to be placed: fwd = distance in front of the character, y = height above its feet. Applied at the end of pose(). */
    _reach(S, fwd, y, w) { if (w > 0.01) this.reachT[S] = [fwd * Math.sin(this.heading + this.yaw), y, Math.min(1, w)]; }
    /** Point a bone (toward its child) at an angle in the plane the character faces: 0 = forward, pi/2 = up, -pi/2 = down, pi = back. */
    _aim(bn, cn, ang, w) {
      const b = this.bones[bn], c = this.bones[cn]; if (!b || !c) return; const v = this._iv, q = this._iq, h = this.heading + this.yaw;
      b.updateWorldMatrix(true, true); const cur = c.getWorldPosition(v[1]).sub(b.getWorldPosition(v[0])).normalize();
      v[2].set(Math.sin(h) * Math.cos(ang), Math.sin(ang), Math.cos(h) * Math.cos(ang));
      q[1].setFromUnitVectors(cur, v[2]); if (w < 1) q[1].slerp(q[3].set(0, 0, 0, 1), 1 - w);
      b.parent.getWorldQuaternion(q[2]); b.quaternion.premultiply(q[1].premultiply(q[3].copy(q[2]).invert()).multiply(q[2]));
    }
    /** Crouch: the hips drop and the feet stay where they were, so the knees fold on their own. */
    _crouch(a) { const d = 0.86 * (1 - Math.cos(a)); this.rootY -= d; this.crouchDrop += d; }
    /** Hands and knees: the back goes level, the limbs are placed after the body (see _crawlLimbs). */
    _crawlPose(c) { this.spinX = c * 1.5; this.rootY -= c * 0.5; this.crawlK = c; this._R('Neck', -c * 0.8); this._R('Head', -c * 0.55); }
    /** Knees under the hips and hands under the shoulders, moving in opposite pairs. */
    _crawlLimbs(c) {
      const S = ['Left', 'Right'], v = this._iv, sh = Math.sin(this.heading + this.yaw);
      for (let i = 0; i < 2; i++) { const ph = this.crawlP + i * Math.PI, fwd = Math.max(0, Math.cos(ph));
        this._aim(S[i] + 'UpLeg', S[i] + 'Leg', -1.5708 + 0.4 * Math.sin(ph), c); this._aim(S[i] + 'Leg', S[i] + 'Foot', 3.19 - 0.3 * fwd, c); this._aim(S[i] + 'Foot', S[i] + 'ToeBase', 3.5, c);
        const arm = this.bones[S[i] + 'Arm']; if (arm) { const hp = ph + Math.PI, ax = arm.getWorldPosition(v[0]).x; this.reachT[S[i]] = [ax + sh * (0.05 + 0.2 * Math.sin(hp)), 0.06 + 0.1 * Math.max(0, Math.cos(hp)), c]; } }
    }
    /** Both hands out on the crate; lean in to push, back to pull. */
    _pushPose(k, pull) {
      this._calm(['LeftArm', 'LeftForeArm', 'RightArm', 'RightForeArm'], k * 0.9);
      for (const S of ['Left', 'Right']) { this._R(S + 'Arm', -k * 1.3); this._R(S + 'ForeArm', -k * 0.25); }
      const gt = this.grabbing ? this.grabHold || 0 : 0, dip = pull || gt > 0 ? sstep(0, 0.2, gt) * (1 - 0.5 * sstep(0.3, 0.7, gt)) : 0;   // get low to take hold, then lean back into the pull
      if (dip > 0.01) { this._crouch(k * dip * 0.6); this._R('Spine1', k * dip * 0.18); }
      this._R('Spine', k * (gt > 0 ? lerp(0.42, pull ? -0.16 : 0.2, sstep(0.22, 0.6, gt)) : 0.3));
      const top = Math.min(1.25, (this.pushTop || 1) - 0.08); this._reach('Left', 0.34, top, k); this._reach('Right', 0.34, top - 0.14, k);   // hands flat on the crate
    }
    _wallPose(k) { this._R('LeftArm', -k * 1.3); this._R('RightArm', -k * 1.6); this._R('LeftUpLeg', -k * 0.5); this._R('LeftLeg', k * 0.6); this._reach('Right', 0.32, 1.6, k); this._reach('Left', 0.32, 1.3, k); }
    /** Hanging by the hands, then pulling up and getting a knee over the edge. */
    _hangPose(k, h) {
      if (h) this._hangU = h.up ? Math.min(1, h.t) : 0;
      const u = this._hangU || 0, e = sstep(0, 0.7, u), bump = sstep(0.3, 0.55, u) * sstep(1, 0.75, u), arm = lerp(-2.72, -0.35, e), fore = -0.15 - 1.3 * Math.sin(Math.PI * e);
      for (const S of ['Left', 'Right']) { this._R(S + 'Arm', k * arm); this._R(S + 'ForeArm', k * fore); }
      this._R('LeftUpLeg', k * (-0.12 - 0.2 * bump)); this._R('LeftLeg', k * (0.3 + 0.3 * bump)); this._R('RightUpLeg', k * (-0.2 - 1.4 * bump)); this._R('RightLeg', k * (0.45 + 1.5 * bump));
      this._R('Spine', k * 0.45 * bump); this._R('Neck', -k * 0.3 * (1 - e));
      if (h) { const hy = h.top - this.y + 0.03, w = k * (1 - sstep(0.55, 0.85, u)); this._reach('Left', this.o.halfWidth + 0.05, hy, w); this._reach('Right', this.o.halfWidth + 0.09, hy, w); }   // hands stay on the ledge while the body rises
    }
    /** Treading water upright when still, a front crawl when moving. */
    _swimPose(k, s) {
      const mk = clamp(s / 1.2, 0, 1), p = this.swimP, a = Math.sin(p), b = -a, t = Math.sin(p * 0.8);
      this.spinX = k * mk * 1.3;
      this._R('LeftArm', k * lerp(-0.7 + 0.25 * t, -1.9 + 1.3 * a, mk)); this._R('RightArm', k * lerp(-0.7 - 0.25 * t, -1.9 + 1.3 * b, mk));
      this._R('LeftForeArm', k * lerp(-0.9, -0.35, mk)); this._R('RightForeArm', k * lerp(-0.9, -0.35, mk));
      this._R('LeftUpLeg', k * lerp(0.25 * a, 0.3 * Math.sin(2 * p), mk)); this._R('RightUpLeg', k * lerp(0.25 * b, -0.3 * Math.sin(2 * p), mk));
      this._R('LeftLeg', k * (0.35 + 0.2 * a)); this._R('RightLeg', k * (0.35 + 0.2 * b));
      this._R('Neck', -k * mk * 0.7); this._R('Head', -k * mk * 0.3);
    }
    /** Knocked down: thrown onto the back, pitched onto the front, or crumpling where it stands; then up through a crouch. */
    _koPose(ko) {
      const o = this.o, sg = ko.sg || -1, crumple = ko.style === 'crumple'; let rot, low, cr = 0, fl;
      if (ko.phase === 'fly') { const e = crumple ? sstep(0.22, 0.6, ko.t) : sstep(0, 0.45, ko.t); rot = 1.25 * e; low = (crumple ? -0.72 : -0.2) * e; fl = e; if (crumple) cr = sstep(0, 0.25, ko.t) * (1 - sstep(0.3, 0.62, ko.t)) * 0.95; }
      else if (ko.phase === 'lie') { const e = sstep(0, 0.12, ko.t); rot = lerp(1.25, 1.5708, e); low = lerp(crumple ? -0.72 : -0.2, o.lieDrop, e); fl = lerp(1, 0.6, e); }
      else { const u = Math.min(1, ko.t / o.getUpTime), e = sstep(0, 0.65, u); rot = 1.5708 * (1 - e); low = o.lieDrop * (1 - sstep(0, 0.55, u)); cr = sstep(0, 0.45, u) * sstep(1, 0.6, u); fl = 0.6 * (1 - e); }
      this.spinX = sg * rot; this.rootY += low; if (cr > 0.01) this._crouch(cr);
      if (sg > 0) { this._R('LeftArm', -fl * 2.5); this._R('RightArm', -fl * 2.1); this._R('LeftForeArm', -fl * 0.6); this._R('RightForeArm', -fl * 0.9); this._R('RightLeg', fl * 0.45); this._R('Neck', -fl * 0.5); }   // face down, arms thrown out ahead
      else { this._R('LeftArm', -fl * 1.9); this._R('RightArm', -fl * 2.3); this._R('LeftUpLeg', -fl * 0.35); this._R('LeftLeg', fl * 0.5); this._R('Neck', -fl * 0.3); }
    }
    /** Limp limbs: while knocked down every arm and leg swings as a weight under gravity, keeps its own momentum as the
        body turns, bends only the way a joint can, and comes to rest on the ground. */
    _limp(dt, ko, m) {
      const B = this.bones, st = this.limpS || (this.limpS = {}), T = this.T, v = this._lv || (this._lv = [new T.Vector3(), new T.Vector3(), new T.Vector3(), new T.Vector3()]);
      const h = this.holder.rotation.y, sh = Math.sin(h), ch = Math.cos(h), ax = v[3].set(ch, 0, -sh), fresh = st.ko !== ko; st.ko = ko;
      const crumple = ko.style === 'crumple', up = ko.phase === 'up' ? sstep(0, 0.45, Math.min(1, ko.t / this.o.getUpTime)) : 0;
      const kA = (ko.phase === 'fly' ? sstep(0.02, crumple ? 0.3 : 0.16, ko.t) : 1) * (1 - up), kL = (ko.phase === 'fly' ? (crumple ? sstep(0.3, 0.62, ko.t) : sstep(0.05, 0.3, ko.t)) : 1) * (1 - up);
      const lying = ko.phase === 'lie', norm = a => Math.atan2(Math.sin(a), Math.cos(a)), gnd = x => (m.ground ? m.ground(x) : 0) + 0.055;
      this.holder.updateMatrixWorld(true);
      const body = () => { if (!B.Spine2 || !B.Hips) return 0; const p0 = B.Spine2.getWorldPosition(v[0]), p1 = B.Hips.getWorldPosition(v[1]); return Math.atan2((p1.x - p0.x) * sh + (p1.z - p0.z) * ch, -(p1.y - p0.y)); };   // which way the trunk points, shoulders to hips
      const seg = (name, child, s, k, G, lim) => { const b = B[name], c = B[child]; if (!b || !c) return null; const p0 = b.getWorldPosition(v[0]), p1 = c.getWorldPosition(v[1]), df = (p1.x - p0.x) * sh + (p1.z - p0.z) * ch, dy = p1.y - p0.y, len = Math.hypot(df, dy) || 0.01, pa = Math.atan2(df, -dy);
        if (fresh || s.p === undefined) { s.p = pa; s.w = (Math.random() - 0.5) * 3; }
        s.w += (-G * Math.sin(s.p) - (lying ? 6 : 2.6) * s.w) * dt; s.p = norm(s.p + s.w * dt);
        const c0 = (p0.y - gnd(p0.x)) / len; if (c0 < 1) { const amin = Math.acos(clamp(c0, -1, 1)); if (Math.abs(s.p) < amin) { s.p = (s.p >= 0 ? 1 : -1) * amin; s.w = 0; } }                // resting on the ground
        const rel = norm(lim.sign * (s.p - lim.ref)); if (rel < lim.min || rel > lim.max) { s.p = norm(lim.ref + lim.sign * clamp(rel, lim.min, lim.max)); s.w = lim.w || 0; }                   // a joint only goes as far as a joint can: this wins over the ground
        this._rot(name, ax, -norm(s.p - pa) * k); return s; };
      for (const S of ['Left', 'Right']) { const a = st[S + 'a'] || (st[S + 'a'] = {}), f = st[S + 'f'] || (st[S + 'f'] = {}), t = st[S + 't'] || (st[S + 't'] = {}), c = st[S + 'c'] || (st[S + 'c'] = {});
        if (kA > 0.01 && seg(S + 'Arm', S + 'ForeArm', a, kA, 46, { ref: body(), sign: 1, min: -1.0, max: 3.0 })) seg(S + 'ForeArm', S + 'Hand', f, kA, 46, { ref: a.p, w: a.w, sign: 1, min: 0, max: 2.5 });
        if (kL > 0.01 && seg(S + 'UpLeg', S + 'Leg', t, kL, 34, { ref: body(), sign: 1, min: -0.3, max: 1.9 })) seg(S + 'Leg', S + 'Foot', c, kL, 34, { ref: t.p, w: t.w, sign: -1, min: 0, max: 2.4 }); }
    }
    /** Read the rig once: when each clip's left foot strikes, ankle height, and the resting arm pose. */
    _measure() {
      const A = this.act, v = this._iv[0], hy = this.holder.rotation.y; this.holder.rotation.y = FACE.right; this.strike = {};
      const only = k => { for (const j in A) A[j].setEffectiveWeight(j === k ? 1 : 0); };
      for (const k of ['walk', 'run']) { only(k); const D = A[k].getClip().duration; let best = 0, bx = -1e9;
        for (let i = 0; i < 32; i++) { A[k].time = D * i / 32; this.mixer.update(0); this.holder.updateMatrixWorld(true); const x = this.bones.LeftFoot.getWorldPosition(v).x; if (x > bx) { bx = x; best = i / 32; } }
        this.strike[k] = best; A[k].time = 0; }
      only('idle'); A.idle.time = 0; this.mixer.update(0); this.holder.updateMatrixWorld(true);
      this.ankleH = this.bones.LeftFoot.getWorldPosition(v).y; this.rest = {};
      for (const n of ['LeftArm', 'LeftForeArm', 'RightArm', 'RightForeArm']) if (this.bones[n]) this.rest[n] = this.bones[n].quaternion.clone();
      this.holder.rotation.y = hy;
    }
    _climbPose(c) {
      const p = this.phase, s = Math.sin(p), l = Math.max(0, -s), r = Math.max(0, s);
      this._R('LeftArm', c * (-2.25 - .55 * s)); this._R('RightArm', c * (-2.25 + .55 * s)); this._R('LeftForeArm', c * (-.55 + .35 * s)); this._R('RightForeArm', c * (-.55 - .35 * s));
      this._R('LeftUpLeg', c * (-.25 - 1.0 * l)); this._R('RightUpLeg', c * (-.25 - 1.0 * r)); this._R('LeftLeg', c * (.45 + 1.25 * l)); this._R('RightLeg', c * (.45 + 1.25 * r));
    }

    // ================= world =================
    /** The level as the controller sees it: solid blocks (crates included), terrain (ground + stairs) and floors. */
    _world(world) {
      const o = this.o, solids = (world.solids || []).slice();
      if (world.crates) for (const c of world.crates) solids.push({ x0: c.x - c.w / 2, x1: c.x + c.w / 2, y0: c.y, y1: c.y + c.h, crate: c });
      const terrain = x => terrainAt(world, x);
      const floor = (x, y) => { let f = terrain(x);
        if (world.platforms && this.dropT <= 0) for (const p of world.platforms) if (x >= p.x0 && x <= p.x1 && p.y <= y + o.stepUp && p.y > f) f = p.y;
        for (const s of solids) if (x >= s.x0 - 0.1 && x <= s.x1 + 0.1 && s.y1 <= y + o.stepUp + 0.01 && s.y1 > f) f = s.y1;
        return f; };
      return { world, solids, terrain, floor };
    }
    /** True when no solid overlaps the body column at x between heights ya and yb. */
    _free(W, x, ya, yb) { const hw = this.o.halfWidth * 0.9; for (const s of W.solids) if (x + hw > s.x0 && x - hw < s.x1 && yb > s.y0 + 0.01 && ya < s.y1 - 0.01) return false; return true; }
    /** Horizontal move with walls: terrain rises, solid blocks, world edges. Pushes crates. Sets this.touch (-1, 0, 1). */
    _moveX(nx, py, H, W, mv) {
      const o = this.o, hw = o.halfWidth, w = W.world; let touch = 0; this.pushing = 0;
      if (w.minX !== undefined) nx = Math.max(w.minX, nx); if (w.maxX !== undefined) nx = Math.min(w.maxX, nx);
      if (W.terrain(nx) > py + o.stepUp + 0.25) { touch = nx > this.x ? 1 : -1; nx = this.x; }
      for (const s of W.solids) {
        if (s.y1 <= py + o.stepUp + 0.01 || s.y0 >= py + H - 0.01) continue;
        if (nx + hw <= s.x0 || nx - hw >= s.x1) continue;
        const side = this.x <= s.x0 - hw + 0.03 ? 1 : this.x >= s.x1 + hw - 0.03 ? -1 : (nx < (s.x0 + s.x1) / 2 ? 1 : -1);
        let tgt = side > 0 ? s.x0 - hw : s.x1 + hw;
        if (s.crate && this.grounded && !this.crouched && !this.action && !this.ko && mv * side > 0.2 && Math.abs(s.y0 - py) < 0.45) {
          const moved = moveCrate(s.crate, nx - tgt, W); s.x0 += moved; s.x1 += moved; tgt += moved; this.pushing = side; this.pushTop = s.crate.h;
        }
        nx = tgt; touch = side;
      }
      if (touch && !this.pushing) this.vx = 0;
      this.touch = touch; return nx;
    }
    /** A ledge within reach of the hands: the top corner of a solid, or the end of a platform. */
    _ledge(W, nx, ny, mv) {
      const o = this.o, hw = o.halfWidth, lo = o.hangDrop - 0.55, hi = o.hangDrop + 0.15;
      const ok = (cx, top, w) => top - ny >= lo && top - ny <= hi && this._free(W, cx + w * 0.4, top + 0.05, top + o.crouchHeight);
      for (const s of W.solids) { if (s.crate) continue;
        if (mv >= -0.1 && Math.abs(nx + hw - s.x0) < 0.14 && ok(s.x0, s.y1, 1)) return { dir: 1, cx: s.x0, top: s.y1 };
        if (mv <= 0.1 && Math.abs(nx - hw - s.x1) < 0.14 && ok(s.x1, s.y1, -1)) return { dir: -1, cx: s.x1, top: s.y1 }; }
      if (W.world.platforms) for (const p of W.world.platforms) {
        if (mv > 0.2 && nx < p.x0 && Math.abs(nx + hw - p.x0) < 0.3 && ok(p.x0, p.y, 1)) return { dir: 1, cx: p.x0, top: p.y };
        if (mv < -0.2 && nx > p.x1 && Math.abs(nx - hw - p.x1) < 0.3 && ok(p.x1, p.y, -1)) return { dir: -1, cx: p.x1, top: p.y }; }
      return null;
    }

    // ================= reactions and items =================
    /** Take a hit. opts: { dir: 1 | -1 (the way the blow travels), power: 0..1, zone: 'head' | 'body' | 'legs',
                            knockdown, out, style: 'back' | 'front' | 'crumple', turn: false to keep facing, flash }.
        The recoil depends on where and how hard: the head snaps back, the body folds over a gut shot, a leg buckles,
        a hard blow sends the character staggering, and one from behind pitches it forward.
        A knockdown falls backward, forward (from behind) or crumples; out:true leaves it down until revive(). */
    hit(opts) {
      opts = opts || {}; if (this.ko) return false;
      const o = this.o, fd = this.facing === 'left' ? -1 : 1, dir = opts.dir === undefined ? -fd : (opts.dir >= 0 ? 1 : -1), p = clamp(opts.power === undefined ? 0.5 : opts.power, 0, 1);
      this.hang = null; this.climbing = false; this.action = null; this.queued = null; this._blend(); if (opts.flash) this.flashT = 0.12;
      if (opts.turn !== false) this.facing = dir > 0 ? 'left' : 'right';
      const behind = (this.facing === 'left' ? -1 : 1) === dir;                         // the blow travels the way the character faces: struck from behind
      if (opts.knockdown || opts.out) { const style = opts.style || (behind ? 'front' : 'back'), cr = style === 'crumple';
        this.ko = { phase: 'fly', t: 0, out: !!opts.out, style, sg: style === 'front' ? 1 : -1 };
        this.vx = dir * o.walkSpeed * (cr ? 0.25 : 0.8 + p); if (!cr) { this.vy = o.jumpSpeed * (0.3 + 0.25 * p); this.grounded = false; this.airTime = 0.2; } }
      else { const zone = opts.zone || 'head', heavy = p > 0.62, name = behind ? 'flinchBack' : heavy ? 'stagger' : opts.twist ? 'flinchTwist' : zone === 'body' ? 'flinchBody' : zone === 'legs' ? 'flinchLegs' : 'flinch';
        this.action = { name, def: MOVES[name], t: 0, dur: MOVES[name].dur, zone }; this.vx = dir * o.walkSpeed * (0.6 + 0.8 * p) * (heavy ? 1.5 : 1); }
      return true;
    }
    /** A looping pose laid over standing (still) or over walking (still:false): fn(hero, seconds, weight). null ends it. */
    setWork(fn, still) { const W = this.work; if (!fn) { if (W) W.on = false; return this; } if (W && W.fn === fn) { W.on = true; return this; } this._blend(); this.work = { fn, t: 0, k: 0, on: true, still: still !== false }; return this; }
    /** Hold the current move still for a moment: the beat of weight when a blow lands. */
    freeze(sec) { this.holdT = Math.max(this.holdT || 0, sec); }
    get down() { return !!this.ko; }
    /** True while a block is up, or while ducked under head height. */
    get blocking() { const a = this.action; return !!(a && a.def.guard && a.t > 0.1 && a.t < 0.85); }
    /** 'head' while leaning or weaving out of the way of a head shot. */
    get evading() { const a = this.action; return a && a.def.evade && a.t > 0.12 && a.t < 0.78 ? a.def.evade : null; }
    get ducking() { const a = this.action; return !!(a && a.def.low && a.t > 0.15 && a.t < 0.8); }
    get out() { return !!(this.ko && this.ko.out); }
    /** Stand a knocked-out character back up. */
    revive() { if (this.ko) { this.ko.out = false; if (this.ko.phase === 'lie') this.ko.t = this.o.downTime; } }
    /** Put something in a hand. item: 'sword' | 'torch' | 'box' | a THREE.Object3D (sized in the rig's bone units) | null to let go.
        opts: { hand: 'right' | 'left', pose: 'low' | 'high' | 'both', bone } */
    hold(item, opts) {
      opts = opts || {}; if (this.held) { this.held.obj.parent.remove(this.held.obj); this.held = null; } if (!item) return this;
      let obj = item, pose = opts.pose, bone = opts.bone, name = 'custom';
      if (typeof item === 'string') { const d = ITEMS[item]; if (!d) return this; obj = d.make(this.T); pose = pose || d.pose; bone = bone || d.bone; name = item; }
      const hand = opts.hand === 'left' ? 'Left' : 'Right', b = this.bones[bone || hand + 'Hand']; if (!b) return this;
      b.add(obj); obj.traverse(q => { q.frustumCulled = false; }); this.held = { obj, hand, pose: pose || 'low', name }; return this;
    }
    /** Leave a mark on the character: mark('bruise' | 'blood' | 'dirt' | 'cut', 'head' | 'body'). Small and matte; they stay until clearMarks() or a new look. */
    mark(kind, zone) {
      const T = this.T, head = zone !== 'body', host = head ? this.headG : this.bones.Spine2; if (!host) return false; const n = this.marksN[head ? 'head' : 'body']; if (n >= (head ? 6 : 7)) return false; this.marksN[head ? 'head' : 'body'] = n + 1;
      const col = { bruise: '#4a2b50', blood: '#6a0c0c', dirt: '#6f5d40', cut: '#74100f' }[kind] || '#6a0c0c', soft = kind === 'bruise' || kind === 'dirt';
      const mat = new T.MeshPhongMaterial({ color: col, transparent: soft, opacity: soft ? 0.5 : 1, shininess: soft ? 2 : 34, specular: soft ? 0x000000 : 0x2a1010, depthWrite: !soft });
      const R = head ? [9.4, 11.6, 10.2, 0, 11.2, 1.2] : this.torso, rr = (a, b) => a + Math.random() * (b - a), side = Math.random() < 0.5 ? -1 : 1;
      const spot = (th, ph, sx, sy) => { const cs = Math.cos(ph), d = new T.Vector3(Math.sin(th) * cs, Math.sin(ph), Math.cos(th) * cs), m = new T.Mesh(this._disc || (this._disc = new T.CircleGeometry(1, 10)), mat);
        m.position.set(R[3] + d.x * R[0] * 1.025, R[4] + d.y * R[1] * 1.025, R[5] + d.z * R[2] * 1.025); m.quaternion.setFromUnitVectors(new T.Vector3(0, 0, 1), new T.Vector3(d.x / R[0], d.y / R[1], d.z / R[2]).normalize()); m.scale.set(sx, sy, 1); m.frustumCulled = false; host.add(m); if (!head) this.parts.push(m); };
      // fighters are mostly seen side-on, so marks sit toward the side of the face and body
      if (head) { if (kind === 'blood') { const where = Math.random(); if (where < 0.3) { spot(side * 0.15, -0.12, 1, 1.1); spot(side * 0.2, -0.32, 0.7, 1.8); }             // nose, running to the lip
          else if (where < 0.68) { const t = side * rr(0.7, 1.1); spot(t, rr(0.32, 0.42), 1.9, 0.6); spot(t, rr(0.02, 0.18), 0.55, 2.4); }                                         // cut over the eye, a line down the cheek
          else { const t = side * rr(0.45, 0.75); spot(t, -0.48, 1.3, 0.7); spot(t, -0.66, 0.5, 1.4); } }                                                                         // split lip, down the chin
        else spot(side * rr(0.7, 1.25), rr(-0.25, 0.28), rr(2.2, 3.1), rr(1.8, 2.6)); }                                                                                           // bruise or dirt on the cheek or jaw
      else if (kind === 'cut') spot(side * rr(0.4, 1.1), rr(-0.3, 0.4), rr(4.5, 7), 0.6);
      else if (kind === 'blood') { const t = side * rr(0.2, 0.9); spot(t, rr(0.25, 0.5), rr(0.8, 1.2), rr(0.9, 1.6)); spot(t + rr(-0.12, 0.12), rr(0, 0.2), rr(0.5, 0.8), rr(0.6, 1.1)); }   // drips on the chest
      else spot(side * rr(0.4, 1.35), rr(-0.45, 0.45), rr(3.2, 5.8), rr(2.4, 4.2));
      return true;
    }
    clearMarks() { for (const z of [this.headG, this.bones.Spine2]) if (z) for (const m of z.children.slice()) if (this._disc && m.geometry === this._disc) z.remove(m); this.marksN = { head: 0, body: 0 }; }
    _calm(names, k) { for (const n of names) { const b = this.bones[n], r = this.rest[n]; if (b && r) b.quaternion.slerp(r, k); } }

    // ================= controller =================
    /** Put the character somewhere, standing still. */
    teleport(x, y, facing) { this.x = x; this.y = y; this.vx = this.vy = 0; this.climbing = false; this.grounded = true; this.action = null; this.hang = null; this.ko = null; this.swimming = false; this.crouched = false; this.jumping = false; this.stepOff = 0;
      if (facing) { this.facing = facing; this.heading = FACE[facing]; } }
    /** input: { move:-1..1, run, jump (this frame), jumpHeld (for variable height), climb:-1..1, crouch, grab (hold to pull crates),
                 face:'front'|'back', action:'punch'... (this frame) }
        world: { groundAt:(x)=>y, platforms:[{x0,x1,y}], ladders:[{x,y0,y1}], stairs:[{x0,x1,y0,y1,steps}],
                 solids:[{x0,x1,y0,y1}], crates:[{x,y,w,h}], water:[{x0,x1,y0,y1}], minX, maxX } */
    update(dt, input, world) {
      dt = Math.min(dt, 0.05); input = input || {}; world = world || {};
      const o = this.o, hw = o.halfWidth, W = this._world(world);
      let mv = clamp(input.move || 0, -1, 1), cl = clamp(input.climb || 0, -1, 1), jump = !!input.jump;
      if (world.actors) this.actors = world.actors;
      if (this.focus && ((this.focus.t -= dt) <= 0 || this.focus.o.ko || this.ko)) this.focus = null;
      if (input.action) this.play(input.action);
      if (this.ko) { const k = this.ko; k.t += dt; mv = 0; cl = 0; jump = false;
        if (k.phase === 'fly' && this.grounded && k.t > (k.style === 'crumple' ? 0.62 : 0.15)) { k.phase = 'lie'; k.t = 0; } else if (k.phase === 'lie' && k.t > o.downTime && !k.out) { k.phase = 'up'; k.t = 0; } else if (k.phase === 'up' && k.t > o.getUpTime) this.ko = null; }
      const act = this.action, lock = act && !act.def.air, air = act && act.def.air; if (lock) { mv = 0; cl = 0; jump = false; } if (air) { cl = 0; jump = false; }
      if (this.grabT > 0) this.grabT -= dt; if (this.wallT > 0) this.wallT -= dt; if (this.swimOutT > 0) this.swimOutT -= dt;
      this.wallSlide = 0; this.grabbing = null; const wasPush = this.pushing;
      const wt = this.swimOutT > 0 || this.ko || this.hang || this.climbing ? null : waterAt(world, this.x, this.y + o.swimChest);

      if (this.hang) {                                           // ---- hanging from a ledge, or climbing up onto it
        const h = this.hang; this.vx = this.vy = 0; this.grounded = false; this.pushing = 0; this.touch = h.dir; this.facing = h.dir > 0 ? 'right' : 'left';
        if (h.up) { h.t += dt / o.climbUpTime; const u = Math.min(1, h.t);
          this.x = h.cx - h.dir * hw + h.dir * (hw + 0.4) * sstep(0.45, 1, u); this.y = h.top - o.hangDrop * (1 - sstep(0, 0.72, u));
          if (u >= 1) { this.hang = null; this.grounded = true; this.y = h.top; this.airTime = 0; } }
        else { h.t += dt; this.x = h.cx - h.dir * hw; this.y = h.top - o.hangDrop;
          if (cl < 0) { this.hang = null; this.grabT = 0.45; }
          else if (jump && mv * h.dir < -0.3) { this.hang = null; this.grabT = 0.3; this.vy = o.jumpSpeed * 0.9; this.vx = -h.dir * o.runSpeed * 0.8; this.lockT = 0.15; this.jumping = true; this.facing = h.dir > 0 ? 'left' : 'right'; }
          else if (cl > 0 || jump || (mv * h.dir > 0.5 && h.t > 0.3)) { h.up = true; h.t = 0; } }
      } else {
        if (!this.climbing && cl !== 0 && world.ladders && !this.ko) for (const L of world.ladders) {
          if (Math.abs(this.x - L.x) < 0.6 && this.y >= L.y0 - 0.1 && this.y <= L.y1 + 0.1 && !(cl < 0 && this.y <= L.y0 + 0.02) && !(cl > 0 && this.y >= L.y1 - 0.02)) { this.climbing = true; this.swimming = false; this.ladder = L; this.vx = this.vy = 0; break; }
        }
        if (this.climbing) {                                     // ---- ladder
          const L = this.ladder, dy = cl * o.climbSpeed * dt; this.pushing = 0;
          this.x += (L.x - this.x) * Math.min(1, dt * 12); this.y += dy; this.phase += dy * 6.6; this.vx = this.vy = 0; this.grounded = false; this.facing = 'back';
          if (this.y >= L.y1) { this.y = L.y1; this.climbing = false; this.grounded = true; }
          else if (this.y <= L.y0) { this.y = L.y0; this.climbing = false; this.grounded = true; }
          else if (jump) { this.climbing = false; this.vy = o.jumpSpeed * 0.55; this.vx = mv * o.walkSpeed; }
        } else if (wt) {                                         // ---- swimming
          this.swimming = true; this.grounded = false; this.crouched = false; this.jumping = false;
          const surf = wt.y1 - o.swimDepth;
          this.vx += (mv * o.swimSpeed * (input.run ? 1.5 : 1) - this.vx) * (1 - Math.exp(-dt * 5));
          let vt = cl ? cl * o.swimSpeed * 0.8 : clamp((surf - this.y) * 3, -2, 2); if (this.y > surf) vt = clamp((surf - this.y) * 6, -4, 0);
          this.vy += (vt - this.vy) * (1 - Math.exp(-dt * 6));
          const nx = this._moveX(this.x + this.vx * dt, this.y, 1.0, W, mv), fl = W.floor(nx, this.y);
          let ny = this.y + this.vy * dt; if (ny < fl) { ny = fl; this.vy = Math.max(0, this.vy); }
          if (jump && this.y > surf - 0.35) { this.vy = o.jumpSpeed * 0.9; this.swimOutT = 0.45; this.swimming = false; this.jumping = true; this.airTime = 0.2; }
          this.x = nx; this.y = ny; this.swimP += (Math.hypot(this.vx, this.vy) * 1.5 + 1.6) * dt;
          if (Math.abs(mv) > 0.1) this.facing = mv > 0 ? 'right' : 'left'; else if (input.face) this.facing = input.face;
        } else {                                                 // ---- on foot or in the air
          this.swimming = false;
          const py = this.y;
          const room = this._free(W, this.x, py + o.crouchHeight, py + o.height);
          this.crouched = !this.ko && ((this.grounded && !!input.crouch) || (this.crouched && !room));       // stays down while there is no headroom
          const H = this.crouched ? o.crouchHeight : o.height;
          if (input.grab && this.grounded && !this.crouched && !act && !this.ko && world.crates) for (const c of world.crates) { if (Math.abs(c.y - py) > 0.45) continue;
            if (Math.abs(c.x - c.w / 2 - this.x - hw) < 0.15) this.grabbing = { c, side: 1 }; else if (Math.abs(this.x - hw - c.x - c.w / 2) < 0.15) this.grabbing = { c, side: -1 }; if (this.grabbing && this.grabbing.c === c) this.pushTop = c.h; }
          this.grabHold = this.grabbing ? (this.grabHold || 0) + dt : 0; if (this.grabbing && this.grabHold < 0.3) mv = 0;   // a beat to bend and take hold
          const pulling = this.grabbing && mv * this.grabbing.side < -0.2;
          if (this.lockT > 0) this.lockT -= dt;
          else if (!air) { const up = this.grounded && mv ? clamp((W.floor(this.x + Math.sign(mv) * 0.5, py) - py) / 0.5, 0, 1) : 0;   // climbing a slope or stairs is slower
            const want = mv * (input.run && !this.crouched ? o.runSpeed : o.walkSpeed) * (this.crouched ? o.crawlFactor : 1) * (wasPush || pulling ? o.pushFactor : 1) * (1 - o.uphillSlow * up),
              a = 1 - Math.exp(-dt * (this.grounded ? o.accel : o.airAccel) * (act && act.def.slide ? 0.28 : 1)); this.vx += (want - this.vx) * a; }
          let nx = this._moveX(this.x + this.vx * dt, py, H, W, mv);
          if (pulling) moveCrate(this.grabbing.c, nx - this.x, W);
          const fl = W.floor(nx, py), was = this.grounded;
          this.vy -= o.gravity * dt;
          if (this.jumping) { if (this.vy <= 0) this.jumping = false; else if (input.jumpHeld === false && this.vy > o.jumpSpeed * o.jumpCut) { this.vy = o.jumpSpeed * o.jumpCut; this.jumping = false; } }   // let go early = short hop
          if (this.touch && !was) { this.wallT = 0.12; this.wallDir = this.touch;
            if (o.wallSlide && this.vy < 0 && mv * this.touch > 0.2 && !act && !this.ko) { this.vy = Math.max(this.vy, -o.wallSlideSpeed); this.wallSlide = this.touch; } }
          let ny = py + this.vy * dt;
          if (this.vy > 0) for (const s of W.solids) if (nx + hw * 0.8 > s.x0 && nx - hw * 0.8 < s.x1 && s.y0 >= py + H - 0.05 && ny + H > s.y0) { ny = s.y0 - H; this.vy = 0; this.jumping = false; }   // ceilings
          if ((ny <= fl && this.vy <= 0) || (was && this.vy <= 0 && py - fl < 0.5)) { if (was && Math.abs(py - fl) > 0.08) this.stepOff += py - fl; ny = fl; this.vy = 0; this.grounded = true; this.airTime = 0; if (air && act.t > .3) { this.action = null; this.vx *= .4; } }
          else { this.grounded = false; this.airTime += dt; }
          if (this.dropT > 0) this.dropT -= dt;
          if (cl < 0 && this.grounded && world.platforms && W.terrain(nx) < ny - 0.05 && W.floor(nx, ny) > W.terrain(nx) && !W.solids.some(s => nx >= s.x0 - 0.1 && nx <= s.x1 + 0.1 && Math.abs(s.y1 - ny) < 0.02)) { this.dropT = 0.25; this.grounded = false; }
          if (jump && room) {
            if ((this.grounded || this.airTime < 0.12) && this.vy <= 0.01) { this.vy = o.jumpSpeed; this.grounded = false; this.airTime = 0.13; this.jumping = true; this.crouched = false; }
            else if (o.wallJump && !this.grounded && this.wallT > 0) { this.vy = o.jumpSpeed * 0.92; this.vx = -this.wallDir * o.runSpeed * 0.85; this.lockT = 0.16; this.wallT = 0; this.jumping = true; this.wallSlide = 0; this.facing = this.wallDir > 0 ? 'left' : 'right'; }   // kick off the wall
          }
          this.x = nx; this.y = ny;
          if (o.ledgeGrab && !this.grounded && this.vy < 2.5 && this.grabT <= 0 && !act && !this.ko) { const g = this._ledge(W, nx, ny, mv); if (g) { this.hang = { dir: g.dir, cx: g.cx, top: g.top, t: 0, up: false }; this.x = g.cx - g.dir * hw; this.y = g.top - o.hangDrop; this.vx = this.vy = 0; this.jumping = false; this.stepOff = 0; } }
          if (!this.action && !this.ko && !this.hang && !(this.lockT > 0)) {
            if (this.grabbing) this.facing = this.grabbing.side > 0 ? 'right' : 'left';
            else if (this.wallSlide) this.facing = this.wallSlide > 0 ? 'right' : 'left';
            else if (input.lock && input.face) this.facing = input.face;                    // hold your facing: step back without turning away
            else if (Math.abs(mv) > 0.1) this.facing = mv > 0 ? 'right' : 'left'; else if (this.focus && this.grounded) this.faceToward(this.focus.o.x); else if (input.face) this.facing = input.face; }
          else if (this.action && this.action.def.social && this.focus) this.faceToward(this.focus.o.x);
        }
      }
      const hx = this.x, hy = this.y; let stair = null;
      if (world.stairs && this.grounded) for (const s of world.stairs) if (hx >= s.x0 - 0.8 && hx <= s.x1 + 0.8 && hy >= Math.min(s.y0, s.y1) - 0.4 && hy <= Math.max(s.y0, s.y1) + 0.4) stair = s;
      this.pose(dt, { speed: this.swimming ? Math.hypot(this.vx, this.vy) : Math.abs(this.vx), vy: this.vy, facing: this.facing, grounded: this.grounded, climbing: this.climbing, crouch: this.crouched && this.grounded,
        ground: dx => W.floor(hx + dx, hy) - hy, stair, x: hx, pull: !!this.grabbing && mv * this.grabbing.side < -0.2 });
    }

    /** Animate one frame (drawn by draw()). motion: { speed, vy, facing, grounded, climbing, climbPhase, crouch, ground, stair, x }
        ground (optional): dx => height of the floor dx units from the character, relative to its feet. Enables foot placement.
        stair + x (optional): the stairs the character is on and its world x. Enables the stair stride.
        Other states are read from the hero itself: hang, swimming, ko, pushing, wallSlide, held. */
    pose(dt, m) {
      if (this.queued) { this.queueT -= dt; const a0 = this.action; if (this.queueT <= 0 || !a0) this.queued = null; else if (a0.t >= a0.def.chain) this.play(this.queued, this.queuedOpts); }
      if (this._pending && (this._pending.t -= dt) <= 0) { const p = this._pending; this._pending = null; if (!this.action && !this.ko && m.grounded) this.play(p.name, { target: p.from, turnOther: false, noAnswer: true }); }
      const o = this.o, A = this.act, w = this.w, act = this.action, ko = this.ko, hang = this.hang, swim = !!this.swimming;
      this.speed = m.speed || 0; if (m.climbPhase !== undefined) this.phase = m.climbPhase;
      let d = FACE[m.facing || 'right'] - this.heading; d = Math.atan2(Math.sin(d), Math.cos(d)); if (Math.abs(d) > 3.0) d = (this.heading > 0 ? -1 : 1) * Math.abs(d);
      this.heading += d * Math.min(1, dt * o.turnRate); this.heading = Math.atan2(Math.sin(this.heading), Math.cos(this.heading));
      this.yaw = act && act.def.yaw ? act.def.yaw(Math.min(1, act.t)) * (m.facing === 'left' ? -1 : 1) : 0; this.holder.rotation.y = this.heading + this.yaw;   // spinning moves turn the whole body
      const s = this.speed, special = !!(m.climbing || act || ko || hang || swim || (this.work && this.work.on && this.work.still)), dir = m.facing === 'left' ? -1 : m.facing === 'right' ? 1 : 0;
      let wi = 0, ww = 0, wr = 0;
      if (special || !m.grounded || m.crouch) wi = 1;
      else { wi = clamp(1 - s / 1.1, 0, 1); wr = sstep(o.walkClipSpeed * 1.4, o.runClipSpeed * 0.88, s) * (1 - wi); ww = 1 - wi - wr; const bk = dir && (this.vx || 0) * dir < -0.2 ? -1 : 1; A.walk.timeScale = bk * clamp(s / o.walkClipSpeed, 0.7, 2.2); A.run.timeScale = bk * clamp(s / o.runClipSpeed, 0.75, 1.9); }
      // stairs: one tread per step walking, two per step running; the clips are locked to the same rhythm
      const stairOn = o.stairStride && m.stair && m.ground && m.x !== undefined && m.grounded && !m.crouch && !special && dir && s > 0.6;
      this.stairW += ((stairOn ? 1 : 0) - this.stairW) * Math.min(1, dt * 10);
      let gait = null;
      if (stairOn && this.stairW > 0.02) { gait = this._gait(m.stair, m.x, dir, s, m.ground);
        for (const k of ['walk', 'run']) { A[k].time = ((this.strike[k] + gait.f[0]) % 1) * A[k].getClip().duration; A[k].timeScale = 0; } }
      const k = Math.min(1, dt * (act ? 18 : o.blendRate)); w.idle += (wi - w.idle) * k; w.walk += (ww - w.walk) * k; w.run += (wr - w.run) * k;
      A.idle.setEffectiveWeight(w.idle); A.walk.setEffectiveWeight(w.walk); A.run.setEffectiveWeight(w.run);
      this.mixer.update(dt);
      if (this.skull && this.faceTex) { this.blinkT -= dt; if (this.blinkT < -0.11) this.blinkT = 2 + Math.random() * 4; const tx = this.faceTex[this.blinkT < 0 || (ko && ko.phase !== 'up') ? 1 : 0]; if (this.skull.material.map !== tx) this.skull.material.map = tx; }   // blink
      this.rootY = 0; this.spinX = 0; this.crouchDrop = 0; this.crawlK = 0; this.reachT.Left = this.reachT.Right = null;
      const ease = (key, on, rate) => { this[key] += ((on ? 1 : 0) - this[key]) * Math.min(1, dt * rate); return this[key]; };
      // something in the hand
      const hd = this.held, hk = ease('holdW', hd && !m.climbing && !ko && !hang && !swim && !m.crouch && !this.pushing, 10);
      if (hd && hk > 0.01) { const S = hd.hand;
        if (hd.pose === 'both') { this._calm(['LeftArm', 'LeftForeArm', 'RightArm', 'RightForeArm'], hk * 0.9); for (const Z of ['Left', 'Right']) { this._R(Z + 'Arm', -hk * 0.55); this._R(Z + 'ForeArm', -hk * 1.25); } }
        else if (hd.pose === 'high') { this._calm([S + 'Arm', S + 'ForeArm'], hk * 0.85); this._R(S + 'Arm', -hk * 0.3); this._R(S + 'ForeArm', -hk * 0.9); }
        else { this._calm([S + 'Arm', S + 'ForeArm'], hk * 0.6); this._R(S + 'ForeArm', -hk * 0.55); } }
      const sk = ease('stanceW', this.stance > 0 && m.grounded && !special && !m.crouch && !(hd && hd.pose === 'both'), 6) * (this.stance || this._st || 0); if (this.stance > 0) this._st = this.stance;
      if (sk > 0.01) { for (const Z of ['Left', 'Right']) if (!(hd && hd.hand === Z)) { this._calm([Z + 'Arm', Z + 'ForeArm'], sk * 0.7); this._R(Z + 'Arm', -sk * (Z === 'Left' ? 0.62 : 0.45)); this._R(Z + 'ForeArm', -sk * (Z === 'Left' ? 1.75 : 1.95)); } this._R('Spine', sk * 0.1); this._R('Neck', -sk * 0.06);
        if (this.restOK) { const g = sk * w.idle; this._R('LeftUpLeg', -g * 0.16); this._R('LeftLeg', g * 0.14); this._R('RightUpLeg', g * 0.1); this._R('RightLeg', g * 0.16); } }   // guard up, one foot forward
      this.cw += ((m.climbing ? 1 : 0) - this.cw) * Math.min(1, dt * 9); if (this.cw > 0.01) this._climbPose(this.cw);
      // crouch: a squat standing still, a crawl when moving
      const cr = ease('crouchW', m.crouch && !act && !ko, 10), cw2 = ease('crawlW', m.crouch && !act && !ko && s > 0.25, 7);
      if (cr > 0.01) { const c = cr * (1 - cw2); if (c > 0.01) { this._crouch(c * .95); this._R('Spine', c * .3); this._R('Neck', -c * .2); } if (cw2 > 0.01) { this.crawlP += s * dt * 3.4; this._crawlPose(cr * cw2); } }
      // standing still: breathing and small shifts of weight, so the stance never looks frozen
      const lf = ease('lifeW', this.restOK && m.grounded && !special && !m.crouch && s < 0.3, 4) * (1 - sk);
      if (lf > 0.02) { const t = (this.lifeT += dt), br = Math.sin(t * 1.7), sw = Math.sin(t * .55); this._R('Spine2', -br * .022 * lf); this._R('Spine1', -br * .01 * lf); this._F('LeftArm', -br * .02 * lf); this._F('RightArm', br * .02 * lf);
        this._R('LeftForeArm', -(.05 + .04 * sw) * lf); this._R('RightForeArm', -(.05 - .04 * sw) * lf); this._F('Spine', sw * .02 * lf); this._U('Spine1', Math.sin(t * .31) * .04 * lf); this._U('Neck', Math.sin(t * .37) * .12 * lf); this._R('Neck', Math.sin(t * .23) * .035 * lf); this.rootY -= (br + 1) * .004 * lf; }
      const pk = ease('pushW', (this.pushing || m.pull || (this.grabbing && this.grabHold > 0)) && !special, 10); if (pk > 0.01) this._pushPose(pk, m.pull);
      if (act) { if (this.holdT > 0) this.holdT -= dt; else act.t += dt / act.dur; const u = Math.min(1, act.t); act.def.pose(this, u);
        { const d = act.def; if (!d.air && (d.strike || d.guard)) {                                   // every blow is thrown from the legs: sink, set the feet apart, lean in
            const e = d.strike ? kf([0, .22, .5, .8, 1], [0, .55, 1, .4, 0], u) : sstep(0, .25, u) * sstep(1, .75, u); this._crouch(e * (d.leg ? 0.3 : 0.5));
            if (!d.leg && !d.yaw) { const A = this.side ? 'Left' : 'Right', Bk = this.side ? 'Right' : 'Left'; this._R(A + 'UpLeg', -e * 0.26); this._R(A + 'Leg', e * 0.16); this._R(Bk + 'UpLeg', e * 0.24); this._R(Bk + 'Leg', e * 0.2); this._R('Spine', e * 0.09); this._R('Neck', -e * 0.07); } } } if (act.t >= 1 && !(act.def.air && !m.grounded && act.t < 1.6)) { this.action = null; this._blend(); } }
      if (this.work) { const Wk = this.work; Wk.t += dt; Wk.k += ((Wk.on && !act && !ko ? 1 : 0) - Wk.k) * Math.min(1, dt * 9); if (Wk.k > 0.01) Wk.fn(this, Wk.t, Wk.k); else if (!Wk.on) this.work = null; }   // a looping task laid over the stance: hammering, searching, stirring a pot
      const inAir = !m.grounded && !special;
      this.airW += ((inAir ? 1 : 0) - this.airW) * Math.min(1, dt * 14);
      if (inAir) { this.airT += dt; this.fallV = m.vy || 0; } else { if (m.grounded && this.airT > 0.18 && !ko) { this.landK = clamp(-this.fallV / 14, 0.3, 1); this.landT = 0; } this.airT = 0; }
      if (this.airW > 0.01) this._airPose(this.airW, clamp((m.vy || 0) / o.jumpSpeed, -1, 1));
      const wk = ease('wallW', this.wallSlide && inAir, 12); if (wk > 0.01) this._wallPose(wk);
      this.landK *= Math.exp(-dt * 8); this.landT = (this.landT || 0) + dt; if (this.landK > 0.02 && !act && !ko) { const l = this.landK * sstep(0, 0.07, this.landT); this._crouch(l * 0.6); this._R('Spine', l * 0.28); }   // the knees give as the weight comes down
      const hgk = ease('hangW', hang, 16); if (hgk > 0.01) this._hangPose(hgk, hang);
      const swk = ease('swimW', swim, 6); if (swk > 0.01) this._swimPose(swk, s);
      if (ko) this._koPose(ko);
      this.stepOff *= Math.exp(-dt * 16); this.spin.position.y = 1 + this.rootY + this.stepOff; this.spin.rotation.x = this.spinX;
      if (this.crouchDrop > 0.005) { this.holder.updateMatrixWorld(true); for (const S of ['Left', 'Right']) { const ft = this.bones[S + 'Foot']; if (ft) { const c = ft.getWorldPosition(this._iv[0]); this._legIK(S, c.x, c.y + this.crouchDrop, 0); } } }
      if (this.crawlK > 0.01) { this.holder.updateMatrixWorld(true); this._crawlLimbs(this.crawlK); }
      const ikOn = o.footIK && !!m.ground && m.grounded && !m.climbing && !(act && act.def.air) && !ko && !hang && !swim && !(m.crouch && s > 0.25);
      this.ikW += ((ikOn ? 1 : 0) - this.ikW) * Math.min(1, dt * 12);
      const plantOn = ikOn && !!act && !act.def.air && m.x !== undefined && !gait && !m.crouch;
      this.plantW += ((plantOn ? 1 : 0) - this.plantW) * Math.min(1, dt * 12); if (!plantOn && this.plantW < 0.03) { const P = this.pl; P.wx[0] = P.wx[1] = null; P.st[0] = P.st[1] = null; P.spread = 0; }
      const plant = this.plantW >= 0.03 && m.x !== undefined ? { x: m.x, w: this.plantW, skip: act && act.def.leg ? (this.side ? 0 : 1) : -1 } : null;
      if (this.ikW > 0.01) this._feet(dt, ikOn ? m.ground : null, dir, gait, plant); else { this.pelv = 0; this.lean = 0; }
      for (const S of ['Left', 'Right']) { const r = this.reachT[S]; if (!r) continue; this.holder.updateMatrixWorld(true);   // hands asked to be somewhere
        for (let i = 0; i < 2; i++) { const c = this.bones[S + 'Hand'].getWorldPosition(this._iv[0]); this._ik2(S + 'Arm', S + 'ForeArm', S + 'Hand', lerp(c.x, r[0], r[2]), lerp(c.y, r[1], r[2]), -1, false); } }
      if (ko) this._limp(dt, ko, m); else if (this.limpS) this.limpS.ko = null;
      // flow: fade out of the previous pose, then remember this one
      const bl = this.blist, bw = this.blendW;
      if (bw > 0.01) { const q = this._iq[0], e = bw * bw * (3 - 2 * bw); for (let i = 0; i < bl.length; i++) { q.copy(bl[i].quaternion); bl[i].quaternion.copy(this.snapQ[i]).slerp(q, 1 - e); } this.blendW = Math.max(0, bw - dt / o.blendTime); }
      if (act) this.smoothT = 0.3; else if (this.smoothT > 0) this.smoothT -= dt;
      if (this.smoothT > 0 && bw <= 0.01) { const q = this._iq, kk = 1 - Math.exp(-dt * o.smooth), mo = o.follow * Math.min(1, this.smoothT / 0.1);
        for (let i = 0; i < bl.length; i++) if (!this.legB[i]) { q[0].copy(bl[i].quaternion);                       // where the move wants the bone
          q[1].copy(this.lastQ[i]).multiply(q[2].copy(this.prevQ[i]).invert());                                      // how it turned last frame
          q[3].set(0, 0, 0, 1).slerp(q[1], mo).multiply(this.lastQ[i]);                                              // carry some of that turn on
          bl[i].quaternion.copy(q[3]).slerp(q[0], kk); } }
      for (let i = 0; i < bl.length; i++) this.prevQ[i].copy(this.lastQ[i]);
      for (let i = 0; i < bl.length; i++) this.lastQ[i].copy(bl[i].quaternion);
      if (this.flashT > 0 || this._flash) { const k = Math.max(0, this.flashT / 0.12) * 0.6; for (const m of this.mats) if (m.emissive) m.emissive.setScalar(k); this._flash = k; this.flashT -= dt; }   // white flash when hit
      this._dirty = true;
    }

    /** Draw onto a 2D canvas with the feet at (sx, sy). pxPerUnit = pixels per world unit. */
    draw(ctx, sx, sy, pxPerUnit, shadow) {
      const s = this.o.view * pxPerUnit, sh = this._sh;
      if (shadow !== false && this.grounded) { ctx.save(); ctx.fillStyle = 'rgba(0,0,0,.13)'; ctx.beginPath(); ctx.ellipse(sx, sy + 2, pxPerUnit * 0.5, pxPerUnit * 0.12, 0, 0, 6.2832); ctx.fill(); ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.beginPath(); ctx.ellipse(sx, sy + 2, pxPerUnit * 0.32, pxPerUnit * 0.075, 0, 0, 6.2832); ctx.fill(); ctx.restore(); }
      if (sh.size !== this.o.size) { sh.renderer.setSize(this.o.size, this.o.size, false); sh.size = this.o.size; }
      if (sh.shared || this._dirty) { sh.renderer.render(this.scene, this.camera); this._dirty = false; }   // a shared renderer draws each character just before it is copied
      ctx.drawImage(this.canvas, sx - s / 2, sy - s * 0.92, s, s);
    }
  }

  /** Make n characters from one model file, parsed once. Needs THREE.SkeletonUtils (three/examples/js/utils/SkeletonUtils.js);
      without it each character parses the file again. opts can be a function of the index. Resolves to an array. */
  PlatformerHero.loadMany = function (THREE, src, n, opts) {
    const o = i => typeof opts === 'function' ? opts(i) : opts;
    if (!THREE.SkeletonUtils) return Promise.all(Array.from({ length: n }, (_, i) => PlatformerHero.load(THREE, src, o(i))));
    return new Promise((res, rej) => { const L = new THREE.GLTFLoader(), ok = g => { try { const scenes = Array.from({ length: n }, (_, i) => i ? THREE.SkeletonUtils.clone(g.scene) : g.scene); res(scenes.map((sc, i) => new PlatformerHero(THREE, { scene: sc, animations: g.animations }, o(i)))); } catch (e) { rej(e); } };
      if (typeof src === 'string') L.load(src, ok, undefined, rej); else L.parse(src, '', ok, rej); });
  };
  /** Pixel ratio of the shared renderer (1 = faster, 2 = sharper). */
  PlatformerHero.setQuality = function (ratio) { const sh = PlatformerHero._shared; if (sh) { sh.renderer.setPixelRatio(ratio); sh.size = 0; } };
  PlatformerHero.itemRot = [Math.PI / 2, 0, 0];   // how built-in items sit in the hand
  /** Crates fall and settle. Call once per frame for the whole level (not per character). */
  PlatformerHero.stepWorld = function (world, dt, gravity) {
    if (!world.crates) return; dt = Math.min(dt, 0.05);
    for (const c of world.crates) { c.vy = (c.vy || 0) - (gravity || 30) * dt; let ny = c.y + c.vy * dt, f = Math.max(terrainAt(world, c.x - c.w * 0.4), terrainAt(world, c.x), terrainAt(world, c.x + c.w * 0.4));
      const tops = (world.solids || []).map(s => s).concat(world.crates.filter(q => q !== c).map(q => ({ x0: q.x - q.w / 2, x1: q.x + q.w / 2, y0: q.y, y1: q.y + q.h })));
      for (const s of tops) if (c.x + c.w / 2 > s.x0 + 0.02 && c.x - c.w / 2 < s.x1 - 0.02 && s.y1 <= c.y + 0.3 && s.y1 > f) f = s.y1;
      if (world.platforms) for (const p of world.platforms) if (c.x >= p.x0 && c.x <= p.x1 && p.y <= c.y + 0.3 && p.y > f) f = p.y;
      if (ny <= f) { ny = f; c.vy = 0; } c.y = ny; }
  };

  /** On-screen touch stick. const stick = PlatformerHero.stick({ side:'left', size:132, parent:document.body })
      Read stick.x (-1 left .. 1 right) and stick.y (-1 down .. 1 up) each frame; stick.active is true while held.
      Feed it straight in: hero.update(dt, { move: stick.x, climb: stick.y > .5 ? 1 : stick.y < -.5 ? -1 : 0 }, world) */
  PlatformerHero.stick = function (opts) {
    const o = Object.assign({ side: 'left', size: 132, margin: 22, dead: 0.18, parent: document.body }, opts || {});
    const base = document.createElement('div'), knob = document.createElement('div'), k = o.size * 0.44, R = (o.size - k) / 2;
    base.style.cssText = 'position:fixed;bottom:' + o.margin + 'px;' + o.side + ':' + o.margin + 'px;width:' + o.size + 'px;height:' + o.size + 'px;border-radius:50%;border:2px solid rgba(255,255,255,.7);background:rgba(10,16,30,.4);touch-action:none;user-select:none;-webkit-user-select:none';
    knob.style.cssText = 'position:absolute;left:50%;top:50%;width:' + k + 'px;height:' + k + 'px;margin:' + (-k / 2) + 'px 0 0 ' + (-k / 2) + 'px;border-radius:50%;background:rgba(255,255,255,.8);pointer-events:none';
    base.appendChild(knob); o.parent.appendChild(base);
    const st = { x: 0, y: 0, active: false, el: base, destroy() { base.remove(); } }; let id = null;
    const set = e => { const r = base.getBoundingClientRect(); let dx = (e.clientX - r.left - r.width / 2) / R, dy = (e.clientY - r.top - r.height / 2) / R; const m = Math.hypot(dx, dy); if (m > 1) { dx /= m; dy /= m; }
      knob.style.transform = 'translate(' + dx * R + 'px,' + dy * R + 'px)'; const g = v => Math.abs(v) < o.dead ? 0 : Math.sign(v) * (Math.abs(v) - o.dead) / (1 - o.dead); st.x = g(dx); st.y = -g(dy); };
    const end = e => { if (e.pointerId !== id) return; id = null; st.x = st.y = 0; st.active = false; knob.style.transform = ''; };
    base.addEventListener('pointerdown', e => { if (id !== null) return; id = e.pointerId; st.active = true; try { base.setPointerCapture(id); } catch (_) {} set(e); e.preventDefault(); });
    base.addEventListener('pointermove', e => { if (e.pointerId === id) set(e); });
    base.addEventListener('pointerup', end); base.addEventListener('pointercancel', end);
    return st;
  };
  PlatformerHero.terrainAt = terrainAt;   // ground + stairs height at x, for drawing your level
  root.PlatformerHero = PlatformerHero;
  if (typeof module !== 'undefined' && module.exports) module.exports = { PlatformerHero };
})(typeof window !== 'undefined' ? window : globalThis);

