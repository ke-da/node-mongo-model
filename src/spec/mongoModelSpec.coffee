mongoModel = require "../mongoModel"

describe 'MongoModel', ->
	model = null
	testCollection = "testModel"
	dbInit = db: "mongodb://localhost/test"

	beforeEach ->
		model = new mongoModel

	it 'should set collectionName', ->
		model.setCollectionName testCollection
		expect(model.collectionName).toEqual testCollection

	it 'should connect to db', ->
		p = (model.constructor.Init dbInit).then ->
			expect(model.db).not.toBe(null)
			console.log "DB Connected"

		waitsFor -> p?.isFulfilled()

	it 'should drop collection', ->
		p = model.db.dropCollectionAsync testCollection
		.then ->
			console.log "Collection Dropped"

		waitsFor -> p?.isFulfilled()
		
	it 'should get right collection', ->
		model.setCollectionName testCollection
		p = model.getCollection().then (col) ->
			expect(typeof col).toBe("object")
			expect(col.collectionName).toBe(testCollection)
			console.log "Got Right collection"

		waitsFor -> p?.isFulfilled()

	it 'should insert to collection', ->
		model.setCollectionName testCollection
		p1 = model.insert([{batch1: 1},{batch2: 2}]).then (docs) ->
			expect(Array.isArray(docs)).toBe(true)
			expect(docs.length).toBe(2)
			console.log docs

		p2 = model.insert(hello: "world").then (doc) ->
			expect(Array.isArray(doc)).toBe(false)
			expect(doc._id).not.toBe(null)
			expect(doc.hello).toBe("world")
			console.log doc

		p = p1.constructor.all([p1,p2]).then ->
			console.log "Insertted"

		waitsFor -> p?.isFulfilled()

	it 'should update collection', ->
		model.setCollectionName testCollection
		p = model.update({hello: "world"}, {hello: 'New world'}).then ([cnt]) ->
			expect(cnt).toBe(1)
			console.log "Updated"

		waitsFor -> p?.isFulfilled()

	it "should upsert row", ->
		model.setCollectionName testCollection
		p = model.upsertBy("hello", {hello: "New world 2", upsertAttr: true}).then (cnt) ->
			expect(cnt).toBe(1)
			console.log "Upsertted"

		waitsFor -> p?.isFulfilled()


	it "should find row with right cnt", ->
		model.setCollectionName testCollection
		p = model.findArray(hello: {$exists: 1}).then (items) ->
			expect(items.length).toBe(2)
			console.log items

		waitsFor -> p?.isFulfilled()


