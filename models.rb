class ExpenseData
	def initialize
		@connection = PG.connect(dbname: 'shell-expenses')

		createtable unless exists?
	end

	def createtable
		puts "Table does not exist..."
		puts "Creating table..."
		@connection.exec <<-SQL 
			CREATE TABLE expenses (
				id serial PRIMARY KEY,
				amount numeric(6, 2) NOT NULL,
				memo text NOT NULL,
				created_on date NOT NULL
				);

			ALTER TABLE expenses ADD CONSTRAINT positive_amount CHECK(amount >= 0.01);
		SQL
	end

	def exists?
		sql = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'expenses';"
		selection = @connection.exec_params(sql)

		return selection[0]["count"] == "1"
	end

	def list
		expenses = @connection.exec "SELECT * FROM expenses"
		displayCount(expenses)
		display(expenses) if expenses.ntuples > 0
	end

	def addExpense!(amount, memo)
		@connection.exec_params("INSERT INTO expenses (amount, memo, created_on) VALUES ($1, $2, NOW());", [amount, memo]).values
	end

	def search(query)
		sql = "SELECT * FROM expenses WHERE memo ILIKE $1"
		expenses = @connection.exec_params(sql, ["%#{query}"])
		puts "We have found the following expenses with that search term:"
		displayCount(expenses)
		display(expenses) if expenses.ntuples > 0
	end

	def delete!(id)
		sql = "SELECT * FROM expenses WHERE id = $1"
		expenses = @connection.exec_params(sql, [id])

		if expenses.ntuples == 1
			sql = "DELETE FROM expenses WHERE id = $1"
			@connection.exec_params(sql, [id])

			puts "Expense #{id} deleted."
			display(expenses)
		else
			puts "There is no expense with the id '#{id}'"
		end
	end

	def clear!
		@connection.exec("DELETE FROM expenses")
		puts "All expenses have been deleted."
	end

	private

	def display(expenses)
		expenses.each do |tuple| 
			columns = [ tuple["id"].rjust(4),
									tuple["created_on"].rjust(12),
									tuple["amount"].rjust(10),
									tuple['memo']]
			puts columns.join(" | ")
		end

		puts "-" * 100

		amount_sum = expenses.inject(0) do |sum, tuple|
			sum + tuple["amount"].to_f
		end

		puts "Total #{amount_sum.to_s.rjust(25)}"
	end

	def displayCount(expenses)
		rows = expenses.ntuples
		if rows == 0
			puts "There are no expenses"
		else 
			puts "There are #{rows} rows."
		end
	end
end

class CLI
	def initialize
		@expenser = ExpenseData.new
	end

	def displayHelp
		puts <<-HELP
			|\H\E\L\P|
			An expense recording program.

			Commands:
				- add AMOUNT MEMO [DATE]  -> records a new expense
				- clear                   -> delete all expenses!
				- list                    -> list all expenses
				- delete NUMBER           -> remove expense by id NUMBER
				- search QUERY            -> list expenses with matching memo field
		HELP
	end

	def pingDB
		
	end

	def run(args)
		if args.length < 1
			puts "\t\t\tERROR: No arguments supplied.\n\n"
			displayHelp
			return -1
		end

		command = args.first.downcase
		if command == "list"
			@expenser.list
		elsif command == "search"
			@expenser.search(args[1])
		elsif command == "clear"
			puts "Are you sure you wish to clear the table. (y/n)"
			response = $stdin.getch
			@expenser.clear! if response == "y"
		elsif command == "delete"
			@expenser.delete(args[1])
		elsif command == "add"
			if args.length < 3
				puts "\n\t\t\tMust supply an amount and memo.\n\n"
			else
				@expenser.addExpense!(args[1], args[2])
			end
		else
			displayHelp
		end
	end
end
