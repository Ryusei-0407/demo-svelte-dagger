package todoapp

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/alpine"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

dagger.#Plan & {
	_nodeModulesMount: "/src/node_modules": {
		dest:     "/src/node_modules"
		type:     "cache"
		contents: core.#CacheDir & {
			id: "modules-cache"
		}
	}
	client: {
		filesystem: {
			"./": read: {
				contents: dagger.#FS
				exclude: [
					"README.md",
					"_build",
					"main.cue",
					"node_modules",
				]
			}
			"./_build": write: contents: actions.build.contents.output
		}
		env: {
			APP_NAME: string
		}
	}

	actions: {
		deps: docker.#Build & {
			steps: [
				alpine.#Build & {
					packages: {
						bash: {}
						yarn: {}
						git: {}
					}
				},
				docker.#Copy & {
					contents: client.filesystem."./".read.contents
					dest:     "/src"
				},
				bash.#Run & {
					workdir: "/src"
					mounts: {
						"/cache/yarn": {
							dest:     "/cache/yarn"
							type:     "cache"
							contents: core.#CacheDir & {
								id: "modules-cache"
							}
						}
						_nodeModulesMount
					}
					script: contents: #"""
						yarn config set cache-folder /cache/yarn
						yarn install
						"""#
				},
			]
		}

		check: bash.#Run & {
			input:   deps.output
			workdir: "/src"
			mounts:  _nodeModulesMount
			script: contents: #"""
				yarn run check
				"""#
		}

		build: {
			run: bash.#Run & {
				input:   deps.output
				mounts:  _nodeModulesMount
				workdir: "/src"
				script: contents: #"""
					yarn run build
					"""#
			}

			contents: core.#Subdir & {
				input: run.output.rootfs
				path:  "/src/build"
			}
		}
	}
}
