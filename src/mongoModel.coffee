# Mongo Data Model Super class promisify

Promise = require 'bluebird'
Mongo = require "mongodb"

class MongoModel

	#Shared DB instance
	db: null

	#Shared cache of MongoDb collection connection
	collections: {}

	### Public ###

	# Set shared DB instance on class prototype
	#
	# db - Mongo.DB
	@setDb: (db) ->
		@::db = db

	# Set shared DB instance on class prototype
	#
	# db - Mongo.DB
	# Returns {Promise}
	@Init: (param) ->
		unless param.db
			throw new Error "Invalid db param"

		return @Connect(param.db).then (db) => @setDb db
			
	# Set shared DB instance on class prototype
	# See {http://mongodb.github.io/node-mongodb-native/api-generated/mongoclient.html#connect}
	#
	# dbPath - Databse URI {String}
	# dbOpt - Databse Option {Object}
	# Returns {Promise}
	@Connect: (dbPath, dbOpt) ->
		mongoClient = Mongo.MongoClient
		mongoConnect = Promise.promisify mongoClient.connect, mongoClient
		return (mongoConnect dbPath, dbOpt).then Promise.promisifyAll

	constructor: (param) ->
		@[k] = v  for own k,v of param
		@data= null

	# Set DB for current class
	# This is class method for {MongoModel::setDb}
	#
	# db - Mongo.db instance {Mongo.DB}
	# Returns {this}
	setDb: (db) ->
		#Detach from shared collections
		@collections = {}
		@db = db
		@

	# Set instance collection name
	# Returns {this}
	setCollectionName: (@collectionName = colName) -> @

	# Get [Mongo.Collection](http://mongodb.github.io/node-mongodb-native/api-generated/collection.html) instance
	# Returns {this}
	getCollection: (colName = @collectionName) ->
		unless @collections[colName]?
			#assign the promise to collection, when its resolved, collection will get reassigned
			promise = @db.createCollectionAsync(colName)
			.then Promise.promisifyAll
			.then (col) =>
				return if colName is @collectionName and @dbIndex
					@ensureIndex(col, @dbIndex).then -> col
				else
					@collections[colName] = col

			@collections[colName] = promise
			return promise

		else if @collections[colName] instanceof Promise
			#If instance stored is promise, wait for the promise to be fulfilled
			return @collections[colName]
		else
			#Acutal mongodb collection instance
			return Promise.resolve @collections[colName]

	ensureIndex: (col, index, indexOpt = {}) ->
		if Array.isArray index
			promises = []
			for i in index
				argvs = if Array.isArray i then [col].concat(i) else [col, i]
				promises.push @ensureIndex argvs...

			return Promise.all(promises)
		else
			return col.ensureIndexAsync index, indexOpt

	insert: (row) ->
		isBatch = Array.isArray row
		@getCollection().then (col) ->
			p = col.insertAsync row
			if isBatch then return p

			#Single record
			unless isBatch then p.then (rows) ->
				[row] = rows
				return row

	update: (query, update, opt = {}) ->
		@getCollection().then (col) ->
			col.updateAsync(query, update, opt)

	upsertBy: (key, row) ->
		Promise.try =>
			unless row[key]?
				throw new Error("Invalid upsert")

			@getCollection().then (col) ->
				query = {}
				query[key] = row[key]
				rowCopy = {}
				rowCopy[k] = v for own k,v of row when k isnt "_id" #not allowed to mod _id

				col.updateAsync(query, {$set: rowCopy}, {upsert: true}).then ([cnt, info]) -> cnt

	find: (argv...) ->
		@getCollection().then (col) => col.find(argv...)

	findOne: (argv...) ->
		@getCollection().then (col) =>
			col.findOneAsync argv...

	findArray: (argv...) ->
		@getCollection().then (col) =>
			cursor = col.find(argv...)
			toArray = Promise.promisify(cursor.toArray, cursor)
			toArray()

	remove: (query, justOne) ->
		@getCollection().then (col) ->
			col.removeAsync query, justOne


	distinct: (key, query, opt) ->
		@getCollection().then (col) ->
			col.distinctAsync key, query, opt

module.exports = MongoModel

