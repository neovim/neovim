// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/* vi:set ts=8 sts=4 sw=4 noet:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

/*
 * memfile_test.c: Unittests for memfile.c
 * Mostly by Ivan Krasilnikov.
 */

#undef NDEBUG
#include <assert.h>

/* Must include main.c because it contains much more than just main() */
#define NO_VIM_MAIN
#include "main.c"

/* This file has to be included because the tested functions are static */
#include "memfile.c"

#define index_to_key(i) ((i) ^ 15167)
#define TEST_COUNT 50000

/*
 * Test mf_hash_*() functions.
 */
    static void
test_mf_hash(void)
{
    mf_hashtab_T   ht;
    mf_hashitem_T  *item;
    blocknr_T      key;
    long_u	   i;
    long_u	   num_buckets;

    mf_hash_init(&ht);

    /* insert some items and check invariants */
    for (i = 0; i < TEST_COUNT; i++)
    {
	assert(ht.mht_count == i);

	/* check that number of buckets is a power of 2 */
	num_buckets = ht.mht_mask + 1;
	assert(num_buckets > 0 && (num_buckets & (num_buckets - 1)) == 0);

	/* check load factor */
	assert(ht.mht_count <= (num_buckets << MHT_LOG_LOAD_FACTOR));

	if (i < (MHT_INIT_SIZE << MHT_LOG_LOAD_FACTOR))
	{
	    /* first expansion shouldn't have occurred yet */
	    assert(num_buckets == MHT_INIT_SIZE);
	    assert(ht.mht_buckets == ht.mht_small_buckets);
	}
	else
	{
	    assert(num_buckets > MHT_INIT_SIZE);
	    assert(ht.mht_buckets != ht.mht_small_buckets);
	}

	key = index_to_key(i);
	assert(mf_hash_find(&ht, key) == NULL);

	/* allocate and add new item */
	item = (mf_hashitem_T *)lalloc_clear(sizeof(*item), FALSE);
	assert(item != NULL);
	item->mhi_key = key;
	mf_hash_add_item(&ht, item);

	assert(mf_hash_find(&ht, key) == item);

	if (ht.mht_mask + 1 != num_buckets)
	{
	    /* hash table was expanded */
	    assert(ht.mht_mask + 1 == num_buckets * MHT_GROWTH_FACTOR);
	    assert(i + 1 == (num_buckets << MHT_LOG_LOAD_FACTOR));
	}
    }

    /* check presence of inserted items */
    for (i = 0; i < TEST_COUNT; i++)
    {
	key = index_to_key(i);
	item = mf_hash_find(&ht, key);
	assert(item != NULL);
	assert(item->mhi_key == key);
    }

    /* delete some items */
    for (i = 0; i < TEST_COUNT; i++)
    {
	if (i % 100 < 70)
	{
	    key = index_to_key(i);
	    item = mf_hash_find(&ht, key);
	    assert(item != NULL);
	    assert(item->mhi_key == key);

	    mf_hash_rem_item(&ht, item);
	    assert(mf_hash_find(&ht, key) == NULL);

	    mf_hash_add_item(&ht, item);
	    assert(mf_hash_find(&ht, key) == item);

	    mf_hash_rem_item(&ht, item);
	    assert(mf_hash_find(&ht, key) == NULL);

	    vim_free(item);
	}
    }

    /* check again */
    for (i = 0; i < TEST_COUNT; i++)
    {
	key = index_to_key(i);
	item = mf_hash_find(&ht, key);

	if (i % 100 < 70)
	{
	    assert(item == NULL);
	}
	else
	{
	    assert(item != NULL);
	    assert(item->mhi_key == key);
	}
    }

    /* free hash table and all remaining items */
    mf_hash_free_all(&ht);
}

    int
main(void)
{
    test_mf_hash();
    return 0;
}
