--!strict
-- Small asynchronous signal used by Player without external dependencies.
local Signal = {}
Signal.__index = Signal
export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal = {
	Connect: (self: Signal, listener: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
}

function Signal.new(spawnFn: ((...any) -> ())?)
	return setmetatable({ listeners = {}, spawn = spawnFn or task.spawn }, Signal)
end

function Signal:Connect(listener: (...any) -> ())
	local listeners = self.listeners
	listeners[listener] = true
	local connection = {}
	function connection:Disconnect()
		listeners[listener] = nil
	end
	return connection
end

function Signal:Fire(...: any)
	for listener in self.listeners do
		self.spawn(listener, ...)
	end
end

return Signal
