


import Link from 'next/link'

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-yellow-100 to-amber-200">
      <div className="container mx-auto px-4 py-8">
        <header className="text-center mb-12">
          <h1 className="text-4xl font-bold text-amber-900 mb-4">
            Aurum Credit v0
          </h1>
          <p className="text-xl text-amber-800">
            Gold-unit lending protocol on Ethereum L2
          </p>
        </header>

        <nav className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-4xl mx-auto">
          <Link href="/borrow" className="bg-white rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow">
            <h2 className="text-2xl font-semibold text-amber-800 mb-3">Borrow</h2>
            <p className="text-gray-600">Take out loans denominated in gold ounces against your collateral</p>
          </Link>

          <Link href="/lend" className="bg-white rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow">
            <h2 className="text-2xl font-semibold text-amber-800 mb-3">Lend</h2>
            <p className="text-gray-600">Provide liquidity and earn protocol fees</p>
          </Link>

          <Link href="/portfolio" className="bg-white rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow">
            <h2 className="text-2xl font-semibold text-amber-800 mb-3">Portfolio</h2>
            <p className="text-gray-600">View your positions and health metrics</p>
          </Link>

          <Link href="/oracle" className="bg-white rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow">
            <h2 className="text-2xl font-semibold text-amber-800 mb-3">Oracle Status</h2>
            <p className="text-gray-600">Monitor price feeds and oracle health</p>
          </Link>

          <Link href="/admin" className="bg-white rounded-lg p-6 shadow-lg hover:shadow-xl transition-shadow">
            <h2 className="text-2xl font-semibold text-amber-800 mb-3">Admin</h2>
            <p className="text-gray-600">Protocol parameter management</p>
          </Link>
        </nav>
      </div>
    </main>
  )
}


