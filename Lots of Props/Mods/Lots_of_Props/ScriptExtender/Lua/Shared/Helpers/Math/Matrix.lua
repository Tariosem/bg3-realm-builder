function ArrayToMat(tbl, rows, cols)
    local result = {}
    for i = 1, rows do
        result[i] = {}
        for j = 1, cols do
            result[i][j] = tbl[(i - 1) * cols + j] or 0
        end
    end
    return result
end

function MatToArray(tbl)
    local result = {}
    for i = 1, #tbl do
        for j = 1, #tbl[i] do
            table.insert(result, tbl[i][j] or 0)
        end
    end
    return Matrix.new(result, #tbl, #tbl[1])
end

local function AbsMatrix(mat)
    local result = {}
    for i = 1, #mat do
        result[i] = math.abs(mat[i])
    end
    return result
end

--- @class Matrix
Matrix = {}
Matrix.__index = Matrix

function Matrix:Abs() return Matrix.new(AbsMatrix(self)) end
function Matrix:Transpose() return Matrix.new(Ext.Math.Transpose(self)) end
function Matrix:Determinant() return Ext.Math.Determinant(self) end
function Matrix:Inverse() return Matrix.new(Ext.Math.Inverse(self)) end

function Matrix.__mul(a, b)
    local t = type(b)
    if t == "table" and #b <= 4 then
        if #b == 3 then
            return Vec3.new(Ext.Math.Mul(a, b))
        elseif #b == 4 then
            return Vec4.new(Ext.Math.Mul(a, b))
        else
            Warning("Mat: Invalid multiplication with table of size " .. #b)
            return Vec3.new({0, 0, 0})
        end
    else
        return Matrix.new(Ext.Math.Mul(a, b))
    end
end

function Matrix.__add(a, b) return Matrix.new(Ext.Math.Add(a, b)) end
function Matrix.__sub(a, b) return Matrix.new(Ext.Math.Sub(a, b)) end
function Matrix.__tostring(a)
    local rows = math.sqrt(#a)
    if rows == math.floor(rows) then
        rows = rows
    else
        --Debug("Mat:__tostring: Non-square matrix, output like array")
        return "{" .. table.concat(a, ", ") .. "}"
    end

    local str = "Mat(\n"
    for i = 1, rows do
        for j = 1, rows do
            local idx = (i - 1) * rows + j
            str = str .. string.format("% .4f", a[idx])
            if j < rows then
                str = str .. ", "
            end
        end
        if i < rows then
            str = str .. "\n"
        end
    end
    str = str .. ")"
    return str
end
   
---@param tbl number[]
---@return Matrix
function Matrix.new(tbl)
    tbl = tbl or {} 
    return setmetatable(tbl, Matrix)
end

function Matrix.identity()
    return Matrix.new({
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        0,0,0,1,
    })
end