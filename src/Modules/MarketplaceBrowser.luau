local AvatarEditorService = game:GetService("AvatarEditorService")

local MarketplaceBrowser = {}

export type Filters = {
	keyword: string,
	category: string,
	sort: string,
	includeOffSale: boolean,
	minPrice: number,
	maxPrice: number,
}

export type Session = {
	key: string,
	pages: any,
	results: { any },
	isFinished: boolean,
}

export type Category = {
	id: string,
	label: string,
	assetTypes: { string }?,
	bundleTypes: { string }?,
}

local ACCESSORY_TYPES = {
	"Hat", "HairAccessory", "FaceAccessory", "NeckAccessory",
	"ShoulderAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
}

local LAYERED_TYPES = {
	"TShirtAccessory", "ShirtAccessory", "PantsAccessory", "JacketAccessory",
	"SweaterAccessory", "ShortsAccessory", "DressSkirtAccessory",
	"LeftShoeAccessory", "RightShoeAccessory",
}

MarketplaceBrowser.CATEGORIES = {
	{ id = "All", label = "All" },
	{ id = "Accessories", label = "Accessories", assetTypes = ACCESSORY_TYPES },
	{ id = "Hair", label = "Hair", assetTypes = { "HairAccessory" } },
	{ id = "Hats", label = "Hats", assetTypes = { "Hat" } },
	{ id = "FaceAccessories", label = "Face Accessories", assetTypes = { "FaceAccessory" } },
	{ id = "BackAccessories", label = "Back Accessories", assetTypes = { "BackAccessory" } },
	{ id = "FrontAccessories", label = "Front Accessories", assetTypes = { "FrontAccessory" } },
	{ id = "NeckAccessories", label = "Neck Accessories", assetTypes = { "NeckAccessory" } },
	{ id = "ShoulderAccessories", label = "Shoulder Accessories", assetTypes = { "ShoulderAccessory" } },
	{ id = "WaistAccessories", label = "Waist Accessories", assetTypes = { "WaistAccessory" } },
	{ id = "LayeredClothing", label = "Layered Clothing", assetTypes = LAYERED_TYPES },
	{ id = "Shirts", label = "Shirts", assetTypes = { "Shirt" } },
	{ id = "Pants", label = "Pants", assetTypes = { "Pants" } },
	{ id = "TShirts", label = "T-Shirts", assetTypes = { "TShirt" } },
	{ id = "Heads", label = "Heads", assetTypes = { "Head" } },
	{ id = "Faces", label = "Faces", assetTypes = { "Face" } },
	{ id = "BodyParts", label = "Body Parts", assetTypes = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } },
	{ id = "Bundles", label = "Bundles / Characters", bundleTypes = { "BodyParts", "DynamicHead", "DynamicHeadAvatar" } },
} :: { Category }

MarketplaceBrowser.SORTS = {
	{ id = "Relevance", label = "Relevance" },
	{ id = "PriceLowToHigh", label = "Price: Low to High" },
	{ id = "PriceHighToLow", label = "Price: High to Low" },
	{ id = "MostFavorited", label = "Most Favorited" },
	{ id = "RecentlyCreated", label = "Recently Created" },
	{ id = "Bestselling", label = "Bestselling" },
}

local cache: { [string]: Session } = {}
local cacheKeys: { string } = {}
local MAX_CACHED_QUERIES = 12

function MarketplaceBrowser.findCategory(id: string): Category
	for _, category in MarketplaceBrowser.CATEGORIES do
		if category.id == id then
			return category
		end
	end
	return MarketplaceBrowser.CATEGORIES[1]
end

local function resolveEnums(enumName: string, names: { string }): { any }
	local resolved: { any } = {}
	for _, name in names do
		local ok, value = pcall(function()
			return ((Enum :: any)[enumName])[name]
		end)
		if ok and typeof(value) == "EnumItem" then
			table.insert(resolved, value)
		end
	end
	return resolved
end

local function cacheKey(filters: Filters): string
	return string.format(
		"%s|%s|%s|%s|%d|%d",
		string.lower(filters.keyword),
		filters.category,
		filters.sort,
		tostring(filters.includeOffSale),
		filters.minPrice,
		filters.maxPrice
	)
end

function MarketplaceBrowser.buildParams(filters: Filters): CatalogSearchParams
	local params = CatalogSearchParams.new()

	local function assign(field: string, value: any)
		pcall(function()
			(params :: any)[field] = value
		end)
	end

	assign("SearchKeyword", filters.keyword)
	assign("IncludeOffSale", filters.includeOffSale)

	local sorts = resolveEnums("CatalogSortType", { filters.sort })
	if sorts[1] then
		assign("SortType", sorts[1])
	end

	local category = MarketplaceBrowser.findCategory(filters.category)
	if category.assetTypes then
		local assetTypes = resolveEnums("AvatarAssetType", category.assetTypes)
		if #assetTypes > 0 then
			assign("AssetTypes", assetTypes)
		end
	elseif category.bundleTypes then
		local bundleTypes = resolveEnums("BundleType", category.bundleTypes)
		if #bundleTypes > 0 then
			assign("BundleTypes", bundleTypes)
		end
	end

	if filters.minPrice > 0 then
		assign("MinPrice", filters.minPrice)
	end
	if filters.maxPrice > 0 then
		assign("MaxPrice", filters.maxPrice)
	end

	return params
end

local function remember(key: string, session: Session)
	if cache[key] == nil then
		table.insert(cacheKeys, key)
	end
	cache[key] = session

	while #cacheKeys > MAX_CACHED_QUERIES do
		local oldest = table.remove(cacheKeys, 1)
		if oldest then
			cache[oldest] = nil
		end
	end
end

function MarketplaceBrowser.search(filters: Filters): (Session?, string?)
	local key = cacheKey(filters)
	local cached = cache[key]
	if cached then
		return cached, nil
	end

	local params = MarketplaceBrowser.buildParams(filters)

	local ok, pages = pcall(function()
		return AvatarEditorService:SearchCatalogAsync(params)
	end)
	if not ok or pages == nil then
		return nil, "Marketplace search failed. Try again."
	end

	local pageOk, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not pageOk or typeof(page) ~= "table" then
		return nil, "Marketplace returned no readable results."
	end

	local session: Session = {
		key = key,
		pages = pages,
		results = page,
		isFinished = pages.IsFinished == true,
	}
	remember(key, session)
	return session, nil
end

function MarketplaceBrowser.loadMore(session: Session): (number, string?)
	if session.isFinished then
		return 0, nil
	end

	local ok, err = pcall(function()
		session.pages:AdvanceToNextPageAsync()
	end)
	if not ok then
		return 0, "Could not load more results."
	end

	local pageOk, page = pcall(function()
		return session.pages:GetCurrentPage()
	end)
	if not pageOk or typeof(page) ~= "table" then
		session.isFinished = true
		return 0, nil
	end

	local added = 0
	for _, entry in page do
		table.insert(session.results, entry)
		added += 1
	end
	session.isFinished = session.pages.IsFinished == true
	if added == 0 then
		session.isFinished = true
	end

	return added, if err ~= nil then tostring(err) else nil
end

function MarketplaceBrowser.clearCache()
	cache = {}
	cacheKeys = {}
end

return MarketplaceBrowser
